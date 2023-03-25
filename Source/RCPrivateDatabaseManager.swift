//
//  RCPrivateDatabaseManager.swift
//  RedCrownedCrane
//
//  Created by forterli on 2023/3/2.
//

#if os(macOS)
import Cocoa
#else
import UIKit
#endif

import CloudKit

final class RCPrivateDatabaseManager: RCDatabaseManager {

    let container: CKContainer
    let database: CKDatabase
    
    let syncObjects: [RCSyncObject]
    
    public init(objects: [RCSyncObject], container: CKContainer) {
        self.syncObjects = objects
        self.container = container
        self.database = container.privateCloudDatabase
    }
    
    func fetchChangesInDatabase(_ callback: ((Error?) -> Void)?) {
        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangeToken)
        
        /// Only update the changeToken when fetch process completes
        changesOperation.changeTokenUpdatedBlock = { [weak self] newToken in
            self?.databaseChangeToken = newToken
        }
        
        
        if #available(iOS 15.0,tvOS 15.0,macOS 12.0,watchOS 8.0, *) {
            changesOperation.fetchDatabaseChangesResultBlock = {
                switch $0 {
                case .success((let newToken, _)):
                    self.databaseChangeToken = newToken
                    self.fetchChangesInZones(callback)
                    break
                case .failure(let error):
                    switch RCErrorHandler.shared.resultType(with: error) {
                    case .success:
                        break
                    case .retry(let timeToWait, _):
                        RCErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait, block: {
                            self.fetchChangesInDatabase(callback)
                        })
                    case .recoverableError(let reason, _):
                        switch reason {
                        case .changeTokenExpired:
                            /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                            self.databaseChangeToken = nil
                            self.fetchChangesInDatabase(callback)
                        default:
                            return
                        }
                    default:
                        return
                    }
                    break
                }
            }
        } else {
            changesOperation.fetchDatabaseChangesCompletionBlock = {
                [weak self]
                newToken, _, error in
                guard let self = self else { return }
                switch RCErrorHandler.shared.resultType(with: error) {
                case .success:
                    self.databaseChangeToken = newToken
                    // Fetch the changes in zone level
                    self.fetchChangesInZones(callback)
                case .retry(let timeToWait, _):
                    RCErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait, block: {
                        self.fetchChangesInDatabase(callback)
                    })
                case .recoverableError(let reason, _):
                    switch reason {
                    case .changeTokenExpired:
                        /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                        self.databaseChangeToken = nil
                        self.fetchChangesInDatabase(callback)
                    default:
                        return
                    }
                default:
                    return
                }
            }
        }
        database.add(changesOperation)
    }
    
    func createCustomZonesIfAllowed() {
        let zonesToCreate = syncObjects.filter { !$0.isCustomZoneCreated }.map { CKRecordZone(zoneID: $0.zoneID) }
        guard zonesToCreate.count > 0 else { return }
        
        let modifyOp = CKModifyRecordZonesOperation(recordZonesToSave: zonesToCreate, recordZoneIDsToDelete: nil)
        modifyOp.modifyRecordZonesCompletionBlock = { [weak self](_, _, error) in
            guard let self = self else { return }
            switch RCErrorHandler.shared.resultType(with: error) {
            case .success:
                self.syncObjects.forEach { object in
                    object.isCustomZoneCreated = true
                    
                    // As we register local database in the first step, we have to force push local objects which
                    // have not been caught to CloudKit to make data in sync
                    DispatchQueue.main.async {
                        object.pushLocalObjectsToCloudKit()
                    }
                }
            case .retry(let timeToWait, _):
                RCErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.createCustomZonesIfAllowed()
                })
            default:
                return
            }
        }
        
        database.add(modifyOp)
    }
    
    func createDatabaseSubscriptionIfHaveNot() {
        #if os(iOS) || os(tvOS) || os(macOS)
        guard !subscriptionIsLocallyCached else { return }
        let subscription = CKDatabaseSubscription(subscriptionID: RedCrownedCraneSubscription.cloudKitPrivateDatabaseSubscriptionID.id)
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent Push
        
        subscription.notificationInfo = notificationInfo
        
        let createOp = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        createOp.modifySubscriptionsCompletionBlock = { _, _, error in
            guard error == nil else { return }
            self.subscriptionIsLocallyCached = true
        }
        createOp.qualityOfService = .utility
        database.add(createOp)
        #endif
    }
    
    func startObservingTermination() {
        #if os(iOS) || os(tvOS)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.cleanUp), name: UIApplication.willTerminateNotification, object: nil)
        
        #elseif os(macOS)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.cleanUp), name: NSApplication.willTerminateNotification, object: nil)
        
        #endif
    }
    
    private func fetchChangesInZones(_ callback: ((Error?) -> Void)? = nil) {
        let changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIds, optionsByRecordZoneID: zoneIdOptions)
        changesOp.fetchAllChanges = true
        
        changesOp.recordZoneChangeTokensUpdatedBlock = { [weak self] zoneId, token, _ in
            guard let self = self else { return }
            guard let syncObject = self.syncObjects.first(where: { $0.zoneID == zoneId }) else { return }
            syncObject.zoneChangesToken = token
        }
        
        changesOp.recordChangedBlock = { [weak self] record in
            /// The Cloud will return the modified record since the last zoneChangesToken, we need to do local cache here.
            /// Handle the record:
            guard let self = self else { return }
            guard let syncObject = self.syncObjects.first(where: { $0.recordType == record.recordType }) else { return }
            if let localModifiedAt = syncObject.fetchObject(recordID: record.recordID)?.modifiedAt, let cloudModifiedAt = record["modifiedAt"] as? Date {
                guard cloudModifiedAt > localModifiedAt else { return }
            }
            syncObject.add(record: record)
        }
        
        changesOp.recordWithIDWasDeletedBlock = { [weak self] recordId, _ in
            guard let self = self else { return }
            guard let syncObject = self.syncObjects.first(where: { $0.zoneID == recordId.zoneID }) else { return }
            syncObject.delete(recordID: recordId)
        }
        
        changesOp.recordZoneFetchCompletionBlock = { [weak self](zoneId ,token, _, _, error) in
            guard let self = self else { return }
            switch RCErrorHandler.shared.resultType(with: error) {
            case .success:
                guard let syncObject = self.syncObjects.first(where: { $0.zoneID == zoneId }) else { return }
                syncObject.zoneChangesToken = token
            case .retry(let timeToWait, _):
                RCErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.fetchChangesInZones(callback)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    guard let syncObject = self.syncObjects.first(where: { $0.zoneID == zoneId }) else { return }
                    syncObject.zoneChangesToken = nil
                    self.fetchChangesInZones(callback)
                default:
                    return
                }
            default:
                return
            }
        }
        
        changesOp.fetchRecordZoneChangesCompletionBlock = { [weak self] error in
            guard let _ = self else { return }
//            self.syncObjects.forEach {
//                $0.resolvePendingRelationships()
//            }
            callback?(error)
        }
        
        database.add(changesOp)
    }
}

extension RCPrivateDatabaseManager {
    /// The changes token, for more please reference to https://developer.apple.com/videos/play/wwdc2016/231/
    var databaseChangeToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: RedCrownedCraneKey.databaseChangesTokenKey.value) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.removeObject(forKey: RedCrownedCraneKey.databaseChangesTokenKey.value)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: RedCrownedCraneKey.databaseChangesTokenKey.value)
        }
    }
    
    var subscriptionIsLocallyCached: Bool {
        get {
            guard let flag = UserDefaults.standard.object(forKey: RedCrownedCraneKey.subscriptionIsLocallyCachedKey.value) as? Bool  else { return false }
            return flag
        }
        set {
            UserDefaults.standard.set(newValue, forKey: RedCrownedCraneKey.subscriptionIsLocallyCachedKey.value)
        }
    }
    
    private var zoneIds: [CKRecordZone.ID] {
        return syncObjects.map { $0.zoneID }
    }
    
    private var zoneIdOptions: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions] {
        return syncObjects.reduce([CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions]()) { (dict, syncObject) -> [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions] in
            var dict = dict
            let zoneChangesOptions = CKFetchRecordZoneChangesOperation.ZoneOptions()
            zoneChangesOptions.previousServerChangeToken = syncObject.zoneChangesToken
            dict[syncObject.zoneID] = zoneChangesOptions
            return dict
        }
    }
    
    @objc func cleanUp() {
        for syncObject in syncObjects {
            syncObject.cleanUp()
        }
    }
}

//
//  RCSynaEngine.swift
//  RedCrownedCrane
//
//  Created by forterli on 2023/3/2.
//

import CloudKit
import UIKit


public final class RCSynaEngine {
    
    private let databaseManager: RCDatabaseManager
    
    public convenience init(objects: [RCRecordConvertible.Type], databaseScope: CKDatabase.Scope = .private, container: CKContainer = .default()) {
        let syncObjects = objects.map {
            RCSyncObject(type: $0)
        }
        switch databaseScope {
        case .private:
            let privateDatabaseManager = RCPrivateDatabaseManager(objects: syncObjects, container: container)
            self.init(databaseManager: privateDatabaseManager)
        case .public:
            let publicDatabaseManager = RCPublicDatabaseManager(objects: syncObjects, container: container)
            self.init(databaseManager: publicDatabaseManager)
        default:
            fatalError("Shared database scope is not supported yet")
        }
    }
    
    private init(databaseManager: RCDatabaseManager) {
        self.databaseManager = databaseManager
        setup()
    }
    
    private func setup() {
        databaseManager.prepare()
        databaseManager.container.accountStatus { [weak self] (status, error) in
            guard let self = self else { return }
            switch status {
            case .available:
                self.databaseManager.createCustomZonesIfAllowed()
                self.databaseManager.fetchChangesInDatabase(nil)
                self.databaseManager.resumeLongLivedOperationIfPossible()
                self.databaseManager.startObservingRemoteChanges()
                self.databaseManager.startObservingTermination()
                self.databaseManager.createDatabaseSubscriptionIfHaveNot()
            case .noAccount, .restricted:
                guard self.databaseManager is RCPublicDatabaseManager else { break }
                self.databaseManager.fetchChangesInDatabase(nil)
                self.databaseManager.resumeLongLivedOperationIfPossible()
                self.databaseManager.startObservingRemoteChanges()
                self.databaseManager.startObservingTermination()
                self.databaseManager.createDatabaseSubscriptionIfHaveNot()
            case .couldNotDetermine:
                break
            case .temporarilyUnavailable:
                break
            @unknown default:
                break
            }
        }
    }
    
}

// MARK: Public Method
extension RCSynaEngine {
    
    /// Fetch data on the CloudKit and merge with local
    ///
    /// - Parameter completionHandler: Supported in the `privateCloudDatabase` when the fetch data process completes, completionHandler will be called. The error will be returned when anything wrong happens. Otherwise the error will be `nil`.
    public func pull(completionHandler: ((Error?) -> Void)? = nil) {
        databaseManager.fetchChangesInDatabase(completionHandler)
    }
    
    /// Push all existing local data to CloudKit
    /// You should NOT to call this method too frequently
    public func pushAll() {
        databaseManager.syncObjects.forEach { $0.pushLocalObjectsToCloudKit() }
    }
    
    public func pushLocalObjectsToCloudKit(object: RCRecordConvertible) {
        pushLocalObjectsToCloudKit(objects: [object])
    }
    
    public func pushLocalObjectsToCloudKit(objects: [RCRecordConvertible]) {
        var recordsToStore = [CKRecord]()
        var recordIDsToDelete = [CKRecord.ID]()
        for item in objects {
            if item.isDeleted {
                recordIDsToDelete.append(item.record.recordID)
            } else {
                recordsToStore.append(item.record)
            }
        }
        self.databaseManager.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete)
    }
    
    
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        if let dict = userInfo as? [String: NSObject], let notification = CKNotification(fromRemoteNotificationDictionary: dict), let subscriptionID = notification.subscriptionID, RedCrownedCraneSubscription.allIDs.contains(subscriptionID) {
            NotificationCenter.default.post(name: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, userInfo: userInfo)
        }
    }

}

public enum Notifications: String, NotificationName {
    case cloudKitDataDidChangeRemotely
}

public enum RedCrownedCraneKey: String {
    /// Tokens
    case databaseChangesTokenKey
    case zoneChangesTokenKey
    
    /// Flags
    case subscriptionIsLocallyCachedKey
    case hasCustomZoneCreatedKey
    
    var value: String {
        return "icecream.keys." + rawValue
    }
}

public enum RedCrownedCraneSubscription: String, CaseIterable {
    case cloudKitPrivateDatabaseSubscriptionID = "private_changes"
    case cloudKitPublicDatabaseSubscriptionID = "cloudKitPublicDatabaseSubcriptionID"
    
    var id: String {
        return rawValue
    }
    
    public static var allIDs: [String] {
        return RedCrownedCraneSubscription.allCases.map { $0.rawValue }
    }
}




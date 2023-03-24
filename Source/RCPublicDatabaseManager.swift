//
//  RCPublicDatabaseManager.swift
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

final class RCPublicDatabaseManager: RCDatabaseManager {

    let container: CKContainer
    let database: CKDatabase
    
    let syncObjects: [RCSyncObject]
    
    init(objects: [RCSyncObject], container: CKContainer) {
        self.syncObjects = objects
        self.container = container
        self.database = container.publicCloudDatabase
    }
    
    func fetchChangesInDatabase(_ callback: ((Error?) -> Void)?) {
        syncObjects.forEach { [weak self] syncObject in
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: syncObject.recordType, predicate: predicate)
            let queryOperation = CKQueryOperation(query: query)
            self?.excuteQueryOperation(queryOperation: queryOperation, on: syncObject, callback: callback)
        }
    }
    
    func createCustomZonesIfAllowed() {
        
    }
    
    func createDatabaseSubscriptionIfHaveNot() {
        syncObjects.forEach { createSubscriptionInPublicDatabase(on: $0) }
    }
    
    func startObservingTermination() {
        #if os(iOS) || os(tvOS)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.cleanUp), name: UIApplication.willTerminateNotification, object: nil)
        
        #elseif os(macOS)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.cleanUp), name: NSApplication.willTerminateNotification, object: nil)
        
        #endif
    }
    
    // MARK: - Private Methods
    private func excuteQueryOperation(queryOperation: CKQueryOperation,on syncObject: RCSyncAble, callback: ((Error?) -> Void)? = nil) {
        queryOperation.recordFetchedBlock = { record in
            syncObject.add(record: record)
        }
        
        queryOperation.queryCompletionBlock = { [weak self] cursor, error in
            guard let self = self else { return }
            if let cursor = cursor {
                let subsequentQueryOperation = CKQueryOperation(cursor: cursor)
                self.excuteQueryOperation(queryOperation: subsequentQueryOperation, on: syncObject, callback: callback)
                return
            }
            switch RCErrorHandler.shared.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    callback?(nil)
                }
            case .retry(let timeToWait, _):
                RCErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.excuteQueryOperation(queryOperation: queryOperation, on: syncObject, callback: callback)
                })
            default:
                break
            }
        }
        
        database.add(queryOperation)
    }
    
    private func createSubscriptionInPublicDatabase(on syncObject: RCSyncAble) {
        #if os(iOS) || os(tvOS) || os(macOS)
        let predict = NSPredicate(value: true)
        let subscription = CKQuerySubscription(recordType: syncObject.recordType, predicate: predict, subscriptionID: RedCrownedCraneSubscription.cloudKitPublicDatabaseSubscriptionID.id, options: [CKQuerySubscription.Options.firesOnRecordCreation, CKQuerySubscription.Options.firesOnRecordUpdate, CKQuerySubscription.Options.firesOnRecordDeletion])
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent Push
        
        subscription.notificationInfo = notificationInfo
        
        let createOp = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        createOp.modifySubscriptionsCompletionBlock = { _, _, _ in
            
        }
        createOp.qualityOfService = .utility
        database.add(createOp)
        #endif
    }
    
    @objc func cleanUp() {
        for syncObject in syncObjects {
            syncObject.cleanUp()
        }
    }
}

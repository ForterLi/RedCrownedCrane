//
//  RCDatabaseManager.swift
//  RedCrownedCrane
//
//  Created by forterli on 2023/3/2.
//

import CloudKit

protocol RCDatabaseManager: AnyObject {
    
    /// A conduit for accessing and performing operations on the data of an app container.
    var database: CKDatabase { get }
    
    /// An encapsulation of content associated with an app.
    var container: CKContainer { get }
    
    var syncObjects: [RCSyncObject] { get }
    
    init(objects: [RCSyncObject], container: CKContainer)
    
    func prepare()
    
    func fetchChangesInDatabase(_ callback: ((Error?) -> Void)?)

    func resumeLongLivedOperationIfPossible()
    
    func createCustomZonesIfAllowed()
    func startObservingRemoteChanges()
    func startObservingTermination()
    func createDatabaseSubscriptionIfHaveNot()
    
    func cleanUp()
}

extension RCDatabaseManager {
    
    func prepare() {
        syncObjects.forEach {
            $0.pipeToEngine = { [weak self] recordsToStore, recordIDsToDelete in
                guard let self = self else { return }
                self.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete)
            }
        }
    }
    
    func resumeLongLivedOperationIfPossible() {
        container.fetchAllLongLivedOperationIDs { [weak self]( opeIDs, error) in
            guard let self = self, error == nil, let ids = opeIDs else { return }
            for id in ids {
                self.container.fetchLongLivedOperation(withID: id, completionHandler: { [weak self](ope, error) in
                    guard let self = self, error == nil else { return }
                    if let modifyOp = ope as? CKModifyRecordsOperation {
                        modifyOp.modifyRecordsCompletionBlock = { (_,_,_) in
                            print("Resume modify records success!")
                        }
                        // The Apple's example code in doc(https://developer.apple.com/documentation/cloudkit/ckoperation/#1666033)
                        // tells we add operation in container. But however it crashes on iOS 15 beta versions.
                        // And the crash log tells us to "CKDatabaseOperations must be submitted to a CKDatabase".
                        // So I guess there must be something changed in the daemon. We temperorily add this availabilty check.
                        if #available(iOS 15, *) {
                            self.database.add(modifyOp)
                        } else {
                            self.container.add(modifyOp)
                        }
                    }
                })
            }
        }
    }
    
    func startObservingRemoteChanges() {
        NotificationCenter.default.addObserver(forName: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, queue: nil, using: { [weak self](_) in
            guard let self = self else { return }
            DispatchQueue.global(qos: .utility).async {
                self.fetchChangesInDatabase(nil)
            }
        })
    }
    
    /// Sync local data to CloudKit
    /// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
    public func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecord.ID], completion: ((Error?) -> ())? = nil) {
        let modifyOpe = CKModifyRecordsOperation(recordsToSave: recordsToStore, recordIDsToDelete: recordIDsToDelete)
        
        if #available(iOS 11.0, OSX 10.13, tvOS 11.0, watchOS 4.0, *) {
            let config = CKOperation.Configuration()
            config.isLongLived = true
            modifyOpe.configuration = config
        } else {
            // Fallback on earlier versions
            modifyOpe.isLongLived = true
        }
        
        // We use .changedKeys savePolicy to do unlocked changes here cause my app is contentious and off-line first
        // Apple suggests using .ifServerRecordUnchanged save policy
        // For more, see Advanced CloudKit(https://developer.apple.com/videos/play/wwdc2014/231/)
        modifyOpe.savePolicy = .changedKeys
        
        // To avoid CKError.partialFailure, make the operation atomic (if one record fails to get modified, they all fail)
        // If you want to handle partial failures, set .isAtomic to false and implement CKOperationResultType .fail(reason: .partialFailure) where appropriate
        modifyOpe.isAtomic = true
        
        modifyOpe.modifyRecordsCompletionBlock = {
            [weak self]
            (_, _, error) in
            
            guard let self = self else { return }
            
            switch RCErrorHandler.shared.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)
                }
            case .retry(let timeToWait, _):
                RCErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait) {
                    self.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            case .chunk:
                /// CloudKit says maximum number of items in a single request is 400.
                /// So I think 300 should be fine by them.
                let chunkedRecords = recordsToStore.chunkItUp(by: 300)
                for chunk in chunkedRecords {
                    self.syncRecordsToCloudKit(recordsToStore: chunk, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            default:
                return
            }
        }
        
        database.add(modifyOpe)
    }
    
}

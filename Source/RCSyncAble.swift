//
//  RCSyncAble.swift
//  RedCrownedCrane
//
//  Created by forterli on 2023/3/2.
//

import CloudKit


protocol RCSyncAble: AnyObject {
    /// CKRecordZone related
    var recordType: String { get }
    var zoneID: CKRecordZone.ID { get }
    
    /// Local storage
    var zoneChangesToken: CKServerChangeToken? { get set }
    var isCustomZoneCreated: Bool { get set }
    
    /// Local Database related
    func cleanUp()
    func add(record: CKRecord)
    func delete(recordID: CKRecord.ID)
        
    /// CloudKit related
    func pushLocalObjectsToCloudKit()
    
    /// Callback
    var pipeToEngine: ((_ recordsToStore: [CKRecord], _ recordIDsToDelete: [CKRecord.ID]) -> ())? { get set }
}



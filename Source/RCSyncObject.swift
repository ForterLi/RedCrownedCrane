//
//  RCSyncObject.swift
//  RedCrownedCrane
//
//  Created by forterli on 2023/3/2.
//

import Foundation
import CloudKit

final class RCSyncObject  {
    
    public var pipeToEngine: ((_ recordsToStore: [CKRecord], _ recordIDsToDelete: [CKRecord.ID]) -> ())?
    
    var T: RCRecordConvertible.Type!
    
    public init(type: RCRecordConvertible.Type) {
        self.T = type
    }

}

// MARK: - Zone information
extension RCSyncObject: RCSyncAble {
    
    public var recordType: String {
        return T.recordType
    }
    
    public var zoneID: CKRecordZone.ID {
        return T.zoneID
    }
    
    public var zoneChangesToken: CKServerChangeToken? {
        get {
            guard let tokenData = UserDefaults.standard.object(forKey: T.recordType + RedCrownedCraneKey.zoneChangesTokenKey.value) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.removeObject(forKey: T.recordType + RedCrownedCraneKey.zoneChangesTokenKey.value)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: T.recordType + RedCrownedCraneKey.zoneChangesTokenKey.value)
        }
    }

    public var isCustomZoneCreated: Bool {
        get {
            guard let flag = UserDefaults.standard.object(forKey: T.recordType + RedCrownedCraneKey.hasCustomZoneCreatedKey.value) as? Bool else { return false }
            return flag
        }
        set {
            UserDefaults.standard.set(newValue, forKey: T.recordType + RedCrownedCraneKey.hasCustomZoneCreatedKey.value)
        }
    }
    
    public func add(record: CKRecord) {
        T.add(record: record)
    }
    
    public func delete(recordID: CKRecord.ID) {
        T.delete(recordID: recordID)
    }
    
    public func fetchObject(recordID: CKRecord.ID) -> RCRecordConvertible? {
        return T.queryObject(identifiable: recordID.recordName)
    }

    public func cleanUp() {
        T.cleanUp()
    }
    
    public func pushLocalObjectsToCloudKit() {
        guard let objects = T.fetchAllObject() else { return }
        var  recordsToStore = [CKRecord]()
        for item in objects {
            recordsToStore.append(item.record)
        }
        pipeToEngine?(recordsToStore, [])
    }
    
}

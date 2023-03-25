//
//  DemoItem.swift
//  RedCrownedCrane
//
//  Created by forterli on 2023/3/20.
//

import UIKit
import GRDB
import CloudKit
import RedCrownedCrane

class DemoItem: Codable, FetchableRecord, PersistableRecord, RCRecordConvertible {

    var name: String = UUID().uuidString
    
    init() {
        
    }
    
    var identifiable: String = UUID().uuidString
    
    var isDeleted: Bool = false
    
    var modifiedAt: Date = Date()
    
    func assembleRecord(record: CKRecord) {
        record["name"] = self.name
        record["isDeleted"] = self.isDeleted
        record["modifiedAt"] = self.modifiedAt
    }
    
    static func parseFromRecord(record: CKRecord) -> RCRecordConvertible? {
        let p = DemoItem()
        p.identifiable = record.recordID.recordName
        p.name = record["name"] as! String
        p.isDeleted = record["isDeleted"] as! Bool
        p.modifiedAt = record["modifiedAt"] as! Date
        return p
    }
    
    static func add(record: CKRecord) {
        let fd = DemoItem()
        fd.identifiable = record.recordID.recordName
        fd.name = record["name"] as! String
        fd.isDeleted = record["isDeleted"] as! Bool
        fd.modifiedAt = record["modifiedAt"] as! Date
        try? dbQueue.write({ db in
            return try? fd.save(db)
        })
    }
    
    static func delete(recordID: CKRecord.ID) {
        let _ = try? dbQueue.write({ db in
            return try? DemoItem.deleteOne(db, key: recordID.recordName)
        })
    }
    
    static func cleanUp() {
        
    }
    
    static func fetchAllObject() -> [RCRecordConvertible]? {
        return try? dbQueue.read { db in
            let items = try DemoItem.fetchAll(db)
            return items
        }
    }
    
    static func queryObject(identifiable: String) -> RCRecordConvertible? {
        return try? dbQueue.read({ db in
            return try? DemoItem.fetchOne(db, key: identifiable)
        })
    }

}

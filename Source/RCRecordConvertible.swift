//
//  RCRecordConvertible.swift
//  RedCrownedCrane
//
//  Created by forterli on 2023/3/2.
//

import Foundation
import CloudKit

public protocol RCRecordConvertible: AnyObject {
    
    /// CKRecordZone related
    static var recordType: String { get }
    static var zoneID: CKRecordZone.ID { get }
    static var databaseScope: CKDatabase.Scope { get }
    
    /// CloudKit related
    var identifiable:String  { get }
    var isDeleted: Bool { get }
    var modifiedAt: Date { get }
    
    func assembleRecord(record: CKRecord) -> Void
    static func parseFromRecord(record: CKRecord) -> RCRecordConvertible?
    
    /// Local Database related
    static func add(record: CKRecord)
    static func delete(recordID: CKRecord.ID)
    static func cleanUp()
    static func fetchAllObject() -> [RCRecordConvertible]?
    static func queryObject(identifiable: String) -> RCRecordConvertible?

}

extension RCRecordConvertible  {
    
    public static var databaseScope: CKDatabase.Scope {
        return .private
    }
    
    public static var recordType: String {
        return className
    }
    
    public static var zoneID: CKRecordZone.ID {
        switch Self.databaseScope {
        case .private:
            return CKRecordZone.ID(zoneName: "\(recordType)sZone", ownerName: CKCurrentUserDefaultName)
        case .public:
            return CKRecordZone.default().zoneID
        default:
            fatalError("Shared Database is not supported now")
        }
    }
    
    internal var recordID: CKRecord.ID {
        return CKRecord.ID(recordName: self.identifiable, zoneID: Self.zoneID)
    }
    
    internal var record: CKRecord {
        let r = CKRecord(recordType: Self.recordType, recordID: recordID)
        assembleRecord(record: r)
        return r
    }
    
    internal static var className: String {
        get {
            var className = NSStringFromClass(self)
            if RCCommons.isSwiftClass(name: className) {
                className = RCCommons.demangleClassName(name: className)!
            }
            return className
        }
    }
    
    internal var className: String {
        get {
            Self.className
        }
    }
}

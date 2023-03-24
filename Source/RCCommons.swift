//
//  RCCommons..swift
//  RedCrownedCrane
//
//  Created by forterli on 2023/3/2.
//


import Foundation

class RCCommons {
    
    static var className: String {
        get {
            var className = NSStringFromClass(self)
            if self.isSwiftClass(name: className) {
                className = self.demangleClassName(name: className)!
            }
            return className
        }
    }

    static func isSwiftClass(name className: String) -> Bool {
        return className.range(of: ".") != nil
    }

    static func demangleClassName(name className: String) -> String? {
        return className.components(separatedBy: ".").last
    }
    
}

public protocol NotificationName {
    var name: Notification.Name { get }
}

extension RawRepresentable where RawValue == String, Self: NotificationName {
    public var name: Notification.Name {
        get {
            return Notification.Name(self.rawValue)
        }
    }
}



// MARK: - Atomic Variable Support
@propertyWrapper
internal struct Atomic<Value> {
    private let queue = DispatchQueue(label: "com.vadimbulavin.atomic")
    private var value: Value

    init(wrappedValue: Value) {
        self.value = wrappedValue
    }
    
    var wrappedValue: Value {
        get {
            return queue.sync { value }
        }
        set {
            queue.sync { value = newValue }
        }
    }
}


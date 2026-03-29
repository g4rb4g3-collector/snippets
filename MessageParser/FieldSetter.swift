import Foundation

/// Type-erased field setter. Maps a JSON key to a direct property write
/// via a ReferenceWritableKeyPath.
struct FieldSetter<Root: AnyObject> {
    let apply: (Root, Any) -> Bool

    static func string(_ keyPath: ReferenceWritableKeyPath<Root, String>) -> FieldSetter {
        FieldSetter { obj, val in
            guard let v = val as? String else { return false }
            obj[keyPath: keyPath] = v
            return true
        }
    }

    static func int(_ keyPath: ReferenceWritableKeyPath<Root, Int>) -> FieldSetter {
        FieldSetter { obj, val in
            if let v = val as? Int { obj[keyPath: keyPath] = v; return true }
            if let v = val as? NSNumber { obj[keyPath: keyPath] = v.intValue; return true }
            return false
        }
    }

    static func double(_ keyPath: ReferenceWritableKeyPath<Root, Double>) -> FieldSetter {
        FieldSetter { obj, val in
            if let v = val as? Double { obj[keyPath: keyPath] = v; return true }
            if let v = val as? NSNumber { obj[keyPath: keyPath] = v.doubleValue; return true }
            return false
        }
    }

    static func bool(_ keyPath: ReferenceWritableKeyPath<Root, Bool>) -> FieldSetter {
        FieldSetter { obj, val in
            if let v = val as? Bool { obj[keyPath: keyPath] = v; return true }
            if let v = val as? NSNumber { obj[keyPath: keyPath] = v.boolValue; return true }
            return false
        }
    }

    static func optional<T>(_ keyPath: ReferenceWritableKeyPath<Root, T?>) -> FieldSetter {
        FieldSetter { obj, val in
            if val is NSNull { obj[keyPath: keyPath] = nil; return true }
            if let v = val as? T { obj[keyPath: keyPath] = v; return true }
            return false
        }
    }
}

/// Protocol for @Observable message classes that register their fields.
protocol PatchableMessage: AnyObject {
    associatedtype Root: AnyObject = Self
    static var fields: [String: FieldSetter<Root>] { get }
    static func create() -> Root
}

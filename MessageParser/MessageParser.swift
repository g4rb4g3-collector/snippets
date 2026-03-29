import Foundation
import Observation
import SwiftUI

// MARK: - Field Registry

/// Type-erased field setter. Maps a JSON key to a direct property write.
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

// MARK: - Message Types

enum MessageType: String {
    case user
    case address
    case contactInfo
}

@Observable
class UserMessage: PatchableMessage {
    var name: String = ""
    var surname: String = ""
    var age: Int = 0

    static let fields: [String: FieldSetter<UserMessage>] = [
        "name":    .string(\.name),
        "surname": .string(\.surname),
        "age":     .int(\.age),
    ]

    static func create() -> UserMessage { UserMessage() }
}

@Observable
class AddressMessage: PatchableMessage {
    var zipcode: String = ""
    var country: String = ""
    var city: String = ""
    var street: String = ""

    static let fields: [String: FieldSetter<AddressMessage>] = [
        "zipcode": .string(\.zipcode),
        "country": .string(\.country),
        "city":    .string(\.city),
        "street":  .string(\.street),
    ]

    static func create() -> AddressMessage { AddressMessage() }
}

@Observable
class ContactInfoMessage: PatchableMessage {
    var phone: String = ""
    var email: String = ""

    static let fields: [String: FieldSetter<ContactInfoMessage>] = [
        "phone": .string(\.phone),
        "email": .string(\.email),
    ]

    static func create() -> ContactInfoMessage { ContactInfoMessage() }
}

// MARK: - Streaming JSON Token Parser

enum JSONToken {
    case objectStart          // {
    case objectEnd            // }
    case arrayStart           // [
    case arrayEnd             // ]
    case comma                // ,
    case colon                // :
    case string(String)       // "..."
    case number(Double)       // 123, 1.5
    case bool(Bool)           // true, false
    case null                 // null
}

struct JSONTokenizer {
    private let data: [UInt8]
    private var pos: Int = 0

    init(_ data: Data) {
        self.data = [UInt8](data)
    }

    mutating func nextToken() -> JSONToken? {
        skipWhitespace()
        guard pos < data.count else { return nil }

        switch data[pos] {
        case UInt8(ascii: "{"):
            pos += 1; return .objectStart
        case UInt8(ascii: "}"):
            pos += 1; return .objectEnd
        case UInt8(ascii: "["):
            pos += 1; return .arrayStart
        case UInt8(ascii: "]"):
            pos += 1; return .arrayEnd
        case UInt8(ascii: ","):
            pos += 1; return .comma
        case UInt8(ascii: ":"):
            pos += 1; return .colon
        case UInt8(ascii: "\""):
            return .string(readString())
        case UInt8(ascii: "t"):
            pos += 4; return .bool(true)
        case UInt8(ascii: "f"):
            pos += 5; return .bool(false)
        case UInt8(ascii: "n"):
            pos += 4; return .null
        default:
            return .number(readNumber())
        }
    }

    private mutating func skipWhitespace() {
        while pos < data.count {
            switch data[pos] {
            case UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\n"), UInt8(ascii: "\r"):
                pos += 1
            default:
                return
            }
        }
    }

    private mutating func readString() -> String {
        pos += 1 // skip opening quote
        var start = pos
        var result = ""
        while pos < data.count && data[pos] != UInt8(ascii: "\"") {
            if data[pos] == UInt8(ascii: "\\") {
                result += String(bytes: data[start..<pos], encoding: .utf8) ?? ""
                pos += 1 // skip backslash
                switch data[pos] {
                case UInt8(ascii: "\""): result += "\""
                case UInt8(ascii: "\\"): result += "\\"
                case UInt8(ascii: "n"):  result += "\n"
                case UInt8(ascii: "t"):  result += "\t"
                case UInt8(ascii: "r"):  result += "\r"
                default: result.append(Character(UnicodeScalar(data[pos])))
                }
                pos += 1
                start = pos
            } else {
                pos += 1
            }
        }
        result += String(bytes: data[start..<pos], encoding: .utf8) ?? ""
        pos += 1 // skip closing quote
        return result
    }

    private mutating func readNumber() -> Double {
        let start = pos
        while pos < data.count {
            let c = data[pos]
            if c == UInt8(ascii: ",") || c == UInt8(ascii: "}") || c == UInt8(ascii: "]")
                || c == UInt8(ascii: " ") || c == UInt8(ascii: "\n") || c == UInt8(ascii: "\r") || c == UInt8(ascii: "\t") {
                break
            }
            pos += 1
        }
        let str = String(bytes: data[start..<pos], encoding: .utf8) ?? "0"
        return Double(str) ?? 0
    }

    /// Skip an entire JSON value (for fields we don't care about).
    mutating func skipValue() {
        skipWhitespace()
        guard pos < data.count else { return }
        switch data[pos] {
        case UInt8(ascii: "{"):
            skipContainer(open: UInt8(ascii: "{"), close: UInt8(ascii: "}"))
        case UInt8(ascii: "["):
            skipContainer(open: UInt8(ascii: "["), close: UInt8(ascii: "]"))
        case UInt8(ascii: "\""):
            _ = readString()
        default:
            _ = nextToken()
        }
    }

    private mutating func skipContainer(open: UInt8, close: UInt8) {
        var depth = 0
        var inString = false
        while pos < data.count {
            let c = data[pos]
            if inString {
                if c == UInt8(ascii: "\\") { pos += 1 }
                else if c == UInt8(ascii: "\"") { inString = false }
            } else {
                if c == UInt8(ascii: "\"") { inString = true }
                else if c == open { depth += 1 }
                else if c == close { depth -= 1; if depth == 0 { pos += 1; return } }
            }
            pos += 1
        }
    }
}

// MARK: - Message Parser

enum ParseError: Error, CustomStringConvertible {
    case missingType
    case invalidJSON

    var description: String {
        switch self {
        case .missingType: return "No 'type' field found"
        case .invalidJSON: return "Invalid JSON structure"
        }
    }
}

@Observable
class MessageParser {
    private(set) var user: UserMessage?
    private(set) var address: AddressMessage?
    private(set) var contactInfo: ContactInfoMessage?

    /// Receives JSON (full or partial), token by token:
    /// 1. Scans for "type" to determine which model to target
    /// 2. Gets or creates the @Observable instance
    /// 3. Applies remaining fields directly to the live object
    @discardableResult
    func receive(_ data: Data) throws -> AnyObject {
        // First pass: find the "type" value
        let messageType = try extractType(from: data)

        // Get or create the target object, then apply fields
        switch messageType {
        case .user:
            let target = user ?? UserMessage.create()
            if user == nil { user = target }
            applyFields(from: data, to: target, using: UserMessage.fields)
            return target

        case .address:
            let target = address ?? AddressMessage.create()
            if address == nil { address = target }
            applyFields(from: data, to: target, using: AddressMessage.fields)
            return target

        case .contactInfo:
            let target = contactInfo ?? ContactInfoMessage.create()
            if contactInfo == nil { contactInfo = target }
            applyFields(from: data, to: target, using: ContactInfoMessage.fields)
            return target
        }
    }

    // MARK: - Private

    /// Scan tokens to find "type" value.
    private func extractType(from data: Data) throws -> MessageType {
        var tokenizer = JSONTokenizer(data)
        guard case .objectStart = tokenizer.nextToken() else {
            throw ParseError.invalidJSON
        }

        while let token = tokenizer.nextToken() {
            guard case .string(let key) = token else { continue }
            guard case .colon = tokenizer.nextToken() else { continue }

            if key == "type" {
                guard case .string(let typeValue) = tokenizer.nextToken(),
                      let type = MessageType(rawValue: typeValue) else {
                    throw ParseError.missingType
                }
                return type
            } else {
                tokenizer.skipValue()
            }
        }
        throw ParseError.missingType
    }

    /// Second pass: tokenize again and apply each field directly to the object.
    private func applyFields<T: AnyObject>(
        from data: Data,
        to target: T,
        using fields: [String: FieldSetter<T>]
    ) {
        var tokenizer = JSONTokenizer(data)
        guard case .objectStart = tokenizer.nextToken() else { return }

        while let token = tokenizer.nextToken() {
            switch token {
            case .objectEnd:
                return
            case .string(let key):
                guard case .colon = tokenizer.nextToken() else { return }

                if key == "type" {
                    tokenizer.skipValue()
                    continue
                }

                if let setter = fields[key] {
                    // Read the value token and apply directly to the object
                    guard let valueToken = tokenizer.nextToken() else { return }
                    let value = tokenToAny(valueToken)
                    _ = setter.apply(target, value)
                } else {
                    tokenizer.skipValue()
                }
            default:
                continue
            }
        }
    }

    private func tokenToAny(_ token: JSONToken) -> Any {
        switch token {
        case .string(let s): return s
        case .number(let n): return n
        case .bool(let b): return b
        case .null: return NSNull()
        default: return NSNull()
        }
    }
}

// MARK: - Service + SwiftUI

class MessageService {
    let parser = MessageParser()

    func onReceived(_ json: Data) throws {
        try parser.receive(json)
    }
}

/// Only re-renders when the specific property it reads changes.
struct UserView: View {
    var user: UserMessage

    var body: some View {
        VStack {
            Text("\(user.name) \(user.surname)")
            Text("Age: \(user.age)")
        }
    }
}

/// Even more granular — this view ONLY re-renders when age changes.
struct UserAgeView: View {
    var user: UserMessage

    var body: some View {
        Text("Age: \(user.age)")
    }
}

struct ContentView: View {
    var service: MessageService

    var body: some View {
        if let user = service.parser.user {
            UserView(user: user)
        }
    }
}

// MARK: - Demo

func demo() {
    let service = MessageService()

    do {
        // 1. Full message arrives — object created, properties set token by token
        try service.onReceived("""
        { "type": "user", "name": "John", "surname": "Doe", "age": 30 }
        """.data(using: .utf8)!)

        let user = service.parser.user!
        print("\(user.name) \(user.surname), age \(user.age)")
        // -> "John Doe, age 30"

        // 2. Partial arrives — SAME object, only "age" property mutated
        //    SwiftUI only re-renders views that read "age"
        try service.onReceived("""
        { "type": "user", "age": 31 }
        """.data(using: .utf8)!)

        print("\(user.name) \(user.surname), age \(user.age)")
        // -> "John Doe, age 31"
        // user is the SAME reference — identity check passes

        // 3. Works for any type
        try service.onReceived("""
        { "type": "address", "zipcode": "10001", "country": "US", "city": "New York", "street": "5th Ave" }
        """.data(using: .utf8)!)

        try service.onReceived("""
        { "type": "address", "city": "Brooklyn" }
        """.data(using: .utf8)!)

        let addr = service.parser.address!
        print("\(addr.street), \(addr.city)")
        // -> "5th Ave, Brooklyn"  (street preserved, city updated)
    } catch {
        print("Error: \(error)")
    }
}

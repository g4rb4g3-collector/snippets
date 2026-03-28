import Foundation
import Observation
import SwiftUI

// MARK: - Message Types (plain Codable structs — no boilerplate)

enum MessageType: String, Codable {
    case user
    case address
    case contactInfo
}

struct UserMessage: Codable {
    let type: MessageType
    var name: String
    var surname: String
    var age: Int
}

struct AddressMessage: Codable {
    let type: MessageType
    var zipcode: String
    var country: String
    var city: String
    var street: String
}

struct ContactInfoMessage: Codable {
    let type: MessageType
    var phone: String
    var email: String
}

// MARK: - Observable Wrapper

/// Generic @Observable box that holds any Codable value.
/// The reference stays the same — assigning .value triggers SwiftUI updates.
@Observable
class ObservableMessage<T: Codable> {
    var value: T

    init(_ value: T) {
        self.value = value
    }
}

// MARK: - PatchDecoder: Custom Decoder that merges partial JSON onto an existing object

/// A custom `Decoder` conforming to Swift's Decoder protocol.
/// For keys present in the patch JSON, it returns the patch value.
/// For missing keys, it falls back to the existing object's encoded values.
/// Usage: `try PatchDecoder.decode(UserMessage.self, from: patchData, onto: existingUser)`
enum PatchDecoder {

    /// Decodes a partial JSON patch on top of an existing Codable value.
    static func decode<T: Codable>(_ type: T.self, from patch: Data, onto existing: T) throws -> T {
        let encoder = JSONEncoder()
        let fallbackData = try encoder.encode(existing)

        guard let fallback = try JSONSerialization.jsonObject(with: fallbackData) as? [String: Any] else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Could not encode existing object"))
        }

        guard let patchDict = try JSONSerialization.jsonObject(with: patch) as? [String: Any] else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Patch is not a JSON object"))
        }

        let decoder = _PatchDecoder(patch: patchDict, fallback: fallback, codingPath: [])
        return try T(from: decoder)
    }
}

// MARK: - Decoder conformance

private struct _PatchDecoder: Decoder {
    let patch: [String: Any]
    let fallback: [String: Any]
    let codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(_PatchKeyedContainer<Key>(patch: patch, fallback: fallback, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath, debugDescription: "PatchDecoder only supports keyed containers"))
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw DecodingError.typeMismatch(Any.self, .init(codingPath: codingPath, debugDescription: "PatchDecoder only supports keyed containers"))
    }
}

// MARK: - KeyedDecodingContainer: reads from patch first, falls back to existing

private struct _PatchKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let patch: [String: Any]
    let fallback: [String: Any]
    let codingPath: [CodingKey]

    var allKeys: [Key] {
        let combined = Set(patch.keys).union(fallback.keys)
        return combined.compactMap { Key(stringValue: $0) }
    }

    func contains(_ key: Key) -> Bool {
        patch[key.stringValue] != nil || fallback[key.stringValue] != nil
    }

    /// Resolve value: patch wins, then fallback.
    private func resolve(_ key: Key) throws -> Any {
        if let value = patch[key.stringValue] { return value }
        if let value = fallback[key.stringValue] { return value }
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Key '\(key.stringValue)' not found in patch or existing object"))
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        let value = try resolve(key)
        return value is NSNull
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try cast(resolve(key), to: type, key: key)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try cast(resolve(key), to: type, key: key)
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        let value = try resolve(key)
        if let v = value as? Double { return v }
        if let v = value as? Int { return Double(v) }
        if let v = value as? NSNumber { return v.doubleValue }
        throw typeMismatch(type, value, key: key)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        Float(try decode(Double.self, forKey: key))
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        let value = try resolve(key)
        if let v = value as? Int { return v }
        if let v = value as? NSNumber { return v.intValue }
        throw typeMismatch(type, value, key: key)
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { Int8(try decode(Int.self, forKey: key)) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { Int16(try decode(Int.self, forKey: key)) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { Int32(try decode(Int.self, forKey: key)) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { Int64(try decode(Int.self, forKey: key)) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { UInt(try decode(Int.self, forKey: key)) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { UInt8(try decode(Int.self, forKey: key)) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { UInt16(try decode(Int.self, forKey: key)) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { UInt32(try decode(Int.self, forKey: key)) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { UInt64(try decode(Int.self, forKey: key)) }

    /// For complex Codable types (enums, nested objects), re-serialize the
    /// resolved value back to JSON and use standard JSONDecoder.
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let value = try resolve(key)
        let data = try JSONSerialization.data(withJSONObject: value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        let value = try resolve(key)
        guard let dict = value as? [String: Any] else {
            throw typeMismatch([String: Any].self, value, key: key)
        }
        let fallbackDict = fallback[key.stringValue] as? [String: Any] ?? [:]
        return KeyedDecodingContainer(_PatchKeyedContainer<NestedKey>(patch: dict, fallback: fallbackDict, codingPath: codingPath + [key]))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath + [key], debugDescription: "Unkeyed containers not supported in PatchDecoder"))
    }

    func superDecoder() throws -> Decoder {
        _PatchDecoder(patch: patch, fallback: fallback, codingPath: codingPath)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        let patchSub = patch[key.stringValue] as? [String: Any] ?? [:]
        let fallbackSub = fallback[key.stringValue] as? [String: Any] ?? [:]
        return _PatchDecoder(patch: patchSub, fallback: fallbackSub, codingPath: codingPath + [key])
    }

    // Helpers

    private func cast<T>(_ value: Any, to type: T.Type, key: Key) throws -> T {
        guard let typed = value as? T else { throw typeMismatch(type, value, key: key) }
        return typed
    }

    private func typeMismatch<T>(_ type: T.Type, _ value: Any, key: Key) -> DecodingError {
        DecodingError.typeMismatch(type, .init(codingPath: codingPath + [key], debugDescription: "Expected \(type), got \(Swift.type(of: value))"))
    }
}

// MARK: - Parser (now uses PatchDecoder)

@Observable
class MessageParser {
    private let decoder = JSONDecoder()

    private(set) var user: ObservableMessage<UserMessage>?
    private(set) var address: ObservableMessage<AddressMessage>?
    private(set) var contactInfo: ObservableMessage<ContactInfoMessage>?

    @discardableResult
    func receive(_ data: Data) throws -> Any {
        let typeContainer = try decoder.decode(TypeContainer.self, from: data)

        switch typeContainer.type {
        case .user:
            if let existing = user {
                existing.value = try PatchDecoder.decode(UserMessage.self, from: data, onto: existing.value)
                return existing
            } else {
                let msg = ObservableMessage(try decoder.decode(UserMessage.self, from: data))
                user = msg
                return msg
            }

        case .address:
            if let existing = address {
                existing.value = try PatchDecoder.decode(AddressMessage.self, from: data, onto: existing.value)
                return existing
            } else {
                let msg = ObservableMessage(try decoder.decode(AddressMessage.self, from: data))
                address = msg
                return msg
            }

        case .contactInfo:
            if let existing = contactInfo {
                existing.value = try PatchDecoder.decode(ContactInfoMessage.self, from: data, onto: existing.value)
                return existing
            } else {
                let msg = ObservableMessage(try decoder.decode(ContactInfoMessage.self, from: data))
                contactInfo = msg
                return msg
            }
        }
    }
}

private struct TypeContainer: Decodable {
    let type: MessageType
}

// MARK: - Service + SwiftUI

class MessageService {
    let parser = MessageParser()

    func onReceived(_ json: Data) throws {
        try parser.receive(json)
    }
}

/// View only needs the wrapper reference — never re-assigned, always reactive.
struct UserView: View {
    var user: ObservableMessage<UserMessage>

    var body: some View {
        VStack {
            Text("\(user.value.name) \(user.value.surname)")
            Text("Age: \(user.value.age)")
        }
    }
}

struct ContentView: View {
    var service: MessageService

    var body: some View {
        if let user = service.parser.user {
            UserView(user: user)  // same reference forever
        }
    }
}

// MARK: - Demo

func demo() {
    let service = MessageService()

    do {
        // Full message arrives
        try service.onReceived("""
        { "type": "user", "name": "John", "surname": "Doe", "age": 30 }
        """.data(using: .utf8)!)

        let userRef = service.parser.user!
        print("\(userRef.value.name), age \(userRef.value.age)")
        // -> "John, age 30"

        // Partial arrives — PatchDecoder reads "age" from patch,
        // falls back to existing object for "name" and "surname"
        try service.onReceived("""
        { "type": "user", "age": 31 }
        """.data(using: .utf8)!)

        print("\(userRef.value.name), age \(userRef.value.age)")
        // -> "John, age 31"

        // PatchDecoder also works standalone, without the parser:
        let address = AddressMessage(type: .address, zipcode: "10001", country: "US", city: "New York", street: "5th Avenue")
        let patched = try PatchDecoder.decode(AddressMessage.self, from: """
        { "city": "Brooklyn", "street": "Atlantic Ave" }
        """.data(using: .utf8)!, onto: address)

        print("\(patched.street), \(patched.city), \(patched.country) \(patched.zipcode)")
        // -> "Atlantic Ave, Brooklyn, US 10001"
    } catch {
        print("Error: \(error)")
    }
}

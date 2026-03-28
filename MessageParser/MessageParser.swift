import Foundation

// MARK: - Message Types

enum MessageType: String, Codable {
    case user
    case address
    case contactInfo
}

protocol Message: Codable {
    var type: MessageType { get }
}

struct UserMessage: Message {
    let type: MessageType
    var name: String
    var surname: String
    var age: Int
}

struct AddressMessage: Message {
    let type: MessageType
    var zipcode: String
    var country: String
    var city: String
    var street: String
}

struct ContactInfoMessage: Message {
    let type: MessageType
    var phone: String
    var email: String
}

// MARK: - Dynamic Parser

enum MessageParseError: Error, CustomStringConvertible {
    case missingType
    case unknownType(String)
    case noExistingMessage(MessageType)

    var description: String {
        switch self {
        case .missingType:
            return "JSON does not contain a 'type' field"
        case .unknownType(let type):
            return "Unknown message type: '\(type)'"
        case .noExistingMessage(let type):
            return "No existing message of type '\(type)' to update"
        }
    }
}

class MessageParser {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// Stored messages keyed by type. Updated on parse and receive.
    private(set) var messages: [MessageType: Message] = [:]

    /// Decodes a full JSON message and stores it.
    func parse(_ data: Data) throws -> Message {
        let typeContainer = try decoder.decode(TypeContainer.self, from: data)

        let message: Message
        switch typeContainer.type {
        case .user:
            message = try decoder.decode(UserMessage.self, from: data)
        case .address:
            message = try decoder.decode(AddressMessage.self, from: data)
        case .contactInfo:
            message = try decoder.decode(ContactInfoMessage.self, from: data)
        }

        messages[message.type] = message
        return message
    }

    /// Receives any JSON (full or partial). Reads the "type" field from the
    /// incoming JSON, finds the stored object of that type, and merges.
    /// If no stored object exists yet, parses as a full message.
    @discardableResult
    func receive(_ data: Data) throws -> Message {
        let typeContainer = try decoder.decode(TypeContainer.self, from: data)

        guard let existing = messages[typeContainer.type] else {
            // First time seeing this type — parse as full message
            return try parse(data)
        }

        // Merge incoming partial JSON on top of the existing object
        let originalData = try encoder.encode(existing)
        guard var original = try JSONSerialization.jsonObject(with: originalData) as? [String: Any] else {
            throw MessageParseError.missingType
        }

        guard let patchDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MessageParseError.missingType
        }

        for (key, value) in patchDict {
            original[key] = value
        }

        let mergedData = try JSONSerialization.data(withJSONObject: original)
        let updated: Message
        switch typeContainer.type {
        case .user:
            updated = try decoder.decode(UserMessage.self, from: mergedData)
        case .address:
            updated = try decoder.decode(AddressMessage.self, from: mergedData)
        case .contactInfo:
            updated = try decoder.decode(ContactInfoMessage.self, from: mergedData)
        }

        messages[typeContainer.type] = updated
        return updated
    }
}

// MARK: - Internal Helpers

private struct TypeContainer: Decodable {
    let type: MessageType
}

/// Wraps arbitrary JSON objects so we can decode a heterogeneous array.
private struct RawJSON: Decodable {
    let value: [String: Any]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let dict = try container.decode([String: AnyCodable].self) as? [String: AnyCodable] else {
            throw MessageParseError.missingType
        }
        value = dict.mapValues { $0.value }
    }
}

private struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = NSNull()
        }
    }
}

// MARK: - Usage Example

func demo() {
    let parser = MessageParser()

    do {
        // 1. Full message arrives
        let fullUser = """
        { "type": "user", "name": "John", "surname": "Doe", "age": 30 }
        """.data(using: .utf8)!
        try parser.receive(fullUser)

        // 2. Partial message arrives — just type + the fields to update
        //    Parser reads "type", finds the stored User, merges automatically
        let partialUser = """
        { "type": "user", "age": 31 }
        """.data(using: .utf8)!
        let updated = try parser.receive(partialUser)

        if let user = updated as? UserMessage {
            print("\(user.name) \(user.surname), age \(user.age)")
            // -> "John Doe, age 31"
        }

        // 3. Works the same for any type
        let fullAddress = """
        { "type": "address", "zipcode": "10001", "country": "US", "city": "New York", "street": "5th Avenue" }
        """.data(using: .utf8)!
        try parser.receive(fullAddress)

        let partialAddress = """
        { "type": "address", "city": "Brooklyn" }
        """.data(using: .utf8)!
        let updatedAddr = try parser.receive(partialAddress)

        if let addr = updatedAddr as? AddressMessage {
            print("\(addr.street), \(addr.city), \(addr.country) \(addr.zipcode)")
            // -> "5th Avenue, Brooklyn, US 10001"
        }

        // 4. Access any stored message by type at any time
        let currentUser = parser.messages[.user]
        print(currentUser!)
    } catch {
        print("Parse error: \(error)")
    }
}

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

    var description: String {
        switch self {
        case .missingType:
            return "JSON does not contain a 'type' field"
        case .unknownType(let type):
            return "Unknown message type: '\(type)'"
        }
    }
}

struct MessageParser {
    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    /// Decodes a single JSON message into the correct concrete type.
    static func parse(_ data: Data) throws -> Message {
        let typeContainer = try decoder.decode(TypeContainer.self, from: data)

        switch typeContainer.type {
        case .user:
            return try decoder.decode(UserMessage.self, from: data)
        case .address:
            return try decoder.decode(AddressMessage.self, from: data)
        case .contactInfo:
            return try decoder.decode(ContactInfoMessage.self, from: data)
        }
    }

    /// Decodes a JSON array of mixed messages.
    static func parseArray(_ data: Data) throws -> [Message] {
        let rawMessages = try decoder.decode([RawJSON].self, from: data)
        return try rawMessages.map { raw in
            let itemData = try JSONSerialization.data(withJSONObject: raw.value)
            return try parse(itemData)
        }
    }

    /// Generic update: merges partial JSON into any existing Message,
    /// returning a new instance with only the provided fields overwritten.
    static func update<T: Message>(_ message: T, with patch: Data) throws -> T {
        // Encode current object to a dictionary
        let originalData = try encoder.encode(message)
        guard var original = try JSONSerialization.jsonObject(with: originalData) as? [String: Any] else {
            throw MessageParseError.missingType
        }

        // Decode the patch into a dictionary
        guard let patchDict = try JSONSerialization.jsonObject(with: patch) as? [String: Any] else {
            throw MessageParseError.missingType
        }

        // Merge patch on top of original (patch wins)
        for (key, value) in patchDict {
            original[key] = value
        }

        // Decode the merged dictionary back into the concrete type
        let mergedData = try JSONSerialization.data(withJSONObject: original)
        return try decoder.decode(T.self, from: mergedData)
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
    let jsonArray = """
    [
        {
            "type": "user",
            "name": "John",
            "surname": "Doe",
            "age": 30
        },
        {
            "type": "address",
            "zipcode": "10001",
            "country": "US",
            "city": "New York",
            "street": "5th Avenue"
        },
        {
            "type": "contactInfo",
            "phone": "+1-555-123-4567",
            "email": "john@example.com"
        }
    ]
    """.data(using: .utf8)!

    do {
        let messages = try MessageParser.parseArray(jsonArray)

        for message in messages {
            switch message {
            case let user as UserMessage:
                print("User: \(user.name) \(user.surname), age \(user.age)")
            case let addr as AddressMessage:
                print("Address: \(addr.street), \(addr.city), \(addr.country) \(addr.zipcode)")
            case let contact as ContactInfoMessage:
                print("Contact: \(contact.phone), \(contact.email)")
            default:
                break
            }
        }

        // Generic update — works on any Message type, no boilerplate needed
        if let user = messages[0] as? UserMessage {
            let patch = """
            { "age": 31, "name": "Jane" }
            """.data(using: .utf8)!

            let updated = try MessageParser.update(user, with: patch)
            print("Updated: \(updated.name) \(updated.surname), age \(updated.age)")
            // -> "Updated: Jane Doe, age 31"
        }
    } catch {
        print("Parse error: \(error)")
    }
}

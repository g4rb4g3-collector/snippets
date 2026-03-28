import Foundation

// MARK: - Message Types

enum MessageType: String, Codable {
    case user
    case address
    case contactInfo
}

protocol Message {
    var type: MessageType { get }
}

struct UserMessage: Message, Codable {
    let type: MessageType
    let name: String
    let surname: String
    let age: Int
}

struct AddressMessage: Message, Codable {
    let type: MessageType
    let zipcode: String
    let country: String
    let city: String
    let street: String
}

struct ContactInfoMessage: Message, Codable {
    let type: MessageType
    let phone: String
    let email: String
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
    } catch {
        print("Parse error: \(error)")
    }
}

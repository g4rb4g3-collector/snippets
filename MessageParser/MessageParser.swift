import Foundation
import Observation
import SwiftUI

// MARK: - Message Types

enum MessageType: String, Codable {
    case user
    case address
    case contactInfo
}

@Observable
class UserMessage: Codable {
    let type: MessageType
    var name: String
    var surname: String
    var age: Int

    init(type: MessageType, name: String, surname: String, age: Int) {
        self.type = type
        self.name = name
        self.surname = surname
        self.age = age
    }

    // Codable conformance — @Observable synthesizes storage that
    // breaks automatic Codable, so we provide it explicitly.
    enum CodingKeys: String, CodingKey {
        case type, name, surname, age
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(MessageType.self, forKey: .type)
        name = try c.decode(String.self, forKey: .name)
        surname = try c.decode(String.self, forKey: .surname)
        age = try c.decode(Int.self, forKey: .age)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(name, forKey: .name)
        try c.encode(surname, forKey: .surname)
        try c.encode(age, forKey: .age)
    }
}

@Observable
class AddressMessage: Codable {
    let type: MessageType
    var zipcode: String
    var country: String
    var city: String
    var street: String

    init(type: MessageType, zipcode: String, country: String, city: String, street: String) {
        self.type = type
        self.zipcode = zipcode
        self.country = country
        self.city = city
        self.street = street
    }

    enum CodingKeys: String, CodingKey {
        case type, zipcode, country, city, street
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(MessageType.self, forKey: .type)
        zipcode = try c.decode(String.self, forKey: .zipcode)
        country = try c.decode(String.self, forKey: .country)
        city = try c.decode(String.self, forKey: .city)
        street = try c.decode(String.self, forKey: .street)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(zipcode, forKey: .zipcode)
        try c.encode(country, forKey: .country)
        try c.encode(city, forKey: .city)
        try c.encode(street, forKey: .street)
    }
}

@Observable
class ContactInfoMessage: Codable {
    let type: MessageType
    var phone: String
    var email: String

    init(type: MessageType, phone: String, email: String) {
        self.type = type
        self.phone = phone
        self.email = email
    }

    enum CodingKeys: String, CodingKey {
        case type, phone, email
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(MessageType.self, forKey: .type)
        phone = try c.decode(String.self, forKey: .phone)
        email = try c.decode(String.self, forKey: .email)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(phone, forKey: .phone)
        try c.encode(email, forKey: .email)
    }
}

// MARK: - Dynamic Parser

enum MessageParseError: Error, CustomStringConvertible {
    case missingType
    case unknownType(String)
    case typeMismatch

    var description: String {
        switch self {
        case .missingType:
            return "JSON does not contain a 'type' field"
        case .unknownType(let type):
            return "Unknown message type: '\(type)'"
        case .typeMismatch:
            return "Incoming type does not match stored object"
        }
    }
}

@Observable
class MessageParser {
    private let decoder = JSONDecoder()

    /// Stored messages keyed by type.
    private(set) var messages: [MessageType: AnyObject] = [:]

    /// Receives any JSON (full or partial). On first receive for a type,
    /// creates the object. On subsequent receives, updates the SAME
    /// object instance in place — SwiftUI views holding a reference
    /// will update automatically.
    @discardableResult
    func receive(_ data: Data) throws -> AnyObject {
        let typeContainer = try decoder.decode(TypeContainer.self, from: data)
        let messageType = typeContainer.type

        if let existing = messages[messageType] {
            try applyPatch(data, to: existing, type: messageType)
            return existing
        } else {
            let message = try createMessage(from: data, type: messageType)
            messages[messageType] = message
            return message
        }
    }

    /// Returns the stored message for a given type, already cast.
    func message<T: AnyObject>(for type: MessageType) -> T? {
        messages[type] as? T
    }

    // MARK: - Private

    private func createMessage(from data: Data, type: MessageType) throws -> AnyObject {
        switch type {
        case .user:
            return try decoder.decode(UserMessage.self, from: data)
        case .address:
            return try decoder.decode(AddressMessage.self, from: data)
        case .contactInfo:
            return try decoder.decode(ContactInfoMessage.self, from: data)
        }
    }

    /// Decodes partial JSON into a dictionary and applies only the
    /// present fields to the existing object — mutating in place.
    private func applyPatch(_ data: Data, to object: AnyObject, type: MessageType) throws {
        guard let patch = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MessageParseError.missingType
        }

        switch type {
        case .user:
            guard let user = object as? UserMessage else { throw MessageParseError.typeMismatch }
            if let name = patch["name"] as? String { user.name = name }
            if let surname = patch["surname"] as? String { user.surname = surname }
            if let age = patch["age"] as? Int { user.age = age }

        case .address:
            guard let addr = object as? AddressMessage else { throw MessageParseError.typeMismatch }
            if let zipcode = patch["zipcode"] as? String { addr.zipcode = zipcode }
            if let country = patch["country"] as? String { addr.country = country }
            if let city = patch["city"] as? String { addr.city = city }
            if let street = patch["street"] as? String { addr.street = street }

        case .contactInfo:
            guard let contact = object as? ContactInfoMessage else { throw MessageParseError.typeMismatch }
            if let phone = patch["phone"] as? String { contact.phone = phone }
            if let email = patch["email"] as? String { contact.email = email }
        }
    }
}

// MARK: - Internal Helpers

private struct TypeContainer: Decodable {
    let type: MessageType
}

// MARK: - Usage Example

// Service layer — holds the parser, not the view
class MessageService {
    let parser = MessageParser()

    func onMessageReceived(_ json: Data) throws {
        try parser.receive(json)
    }
}

// SwiftUI view — holds a reference to the SAME object.
// When parser.receive() mutates properties in place,
// @Observable triggers a view update automatically.
struct UserView: View {
    var user: UserMessage  // same reference from parser

    var body: some View {
        VStack {
            Text("\(user.name) \(user.surname)")
            Text("Age: \(user.age)")
        }
    }
}

struct ContentView: View {
    var service: MessageService

    var body: some View {
        // Get the stored reference — stays the same across updates
        if let user: UserMessage = service.parser.message(for: .user) {
            UserView(user: user)
        }
    }
}

func demo() {
    let service = MessageService()

    do {
        // 1. Full message arrives — object created
        try service.onMessageReceived("""
        { "type": "user", "name": "John", "surname": "Doe", "age": 30 }
        """.data(using: .utf8)!)

        let user: UserMessage = service.parser.message(for: .user)!
        print("\(user.name), age \(user.age)")  // -> "John, age 30"

        // 2. Partial arrives — SAME object mutated in place
        try service.onMessageReceived("""
        { "type": "user", "age": 31 }
        """.data(using: .utf8)!)

        // Same reference, updated value — SwiftUI view refreshes automatically
        print("\(user.name), age \(user.age)")  // -> "John, age 31"
    } catch {
        print("Error: \(error)")
    }
}

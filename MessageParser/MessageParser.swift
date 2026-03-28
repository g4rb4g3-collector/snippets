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

// MARK: - Parser

enum MessageParseError: Error, CustomStringConvertible {
    case missingType
    case invalidJSON

    var description: String {
        switch self {
        case .missingType: return "JSON does not contain a 'type' field"
        case .invalidJSON: return "Could not parse JSON as dictionary"
        }
    }
}

@Observable
class MessageParser {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private(set) var user: ObservableMessage<UserMessage>?
    private(set) var address: ObservableMessage<AddressMessage>?
    private(set) var contactInfo: ObservableMessage<ContactInfoMessage>?

    /// Receives any JSON — full or partial. Reads "type" to dispatch,
    /// creates the object on first receive, merges in place on subsequent ones.
    @discardableResult
    func receive(_ data: Data) throws -> Any {
        let typeContainer = try decoder.decode(TypeContainer.self, from: data)

        switch typeContainer.type {
        case .user:
            if let existing = user {
                existing.value = try merge(existing.value, with: data)
                return existing
            } else {
                let msg = ObservableMessage(try decoder.decode(UserMessage.self, from: data))
                user = msg
                return msg
            }

        case .address:
            if let existing = address {
                existing.value = try merge(existing.value, with: data)
                return existing
            } else {
                let msg = ObservableMessage(try decoder.decode(AddressMessage.self, from: data))
                address = msg
                return msg
            }

        case .contactInfo:
            if let existing = contactInfo {
                existing.value = try merge(existing.value, with: data)
                return existing
            } else {
                let msg = ObservableMessage(try decoder.decode(ContactInfoMessage.self, from: data))
                contactInfo = msg
                return msg
            }
        }
    }

    /// Generic dictionary merge: encode existing → dict, merge patch → decode back.
    /// Works with ANY Codable type, no per-property code needed.
    private func merge<T: Codable>(_ existing: T, with patch: Data) throws -> T {
        let originalData = try encoder.encode(existing)
        guard var dict = try JSONSerialization.jsonObject(with: originalData) as? [String: Any] else {
            throw MessageParseError.invalidJSON
        }

        guard let patchDict = try JSONSerialization.jsonObject(with: patch) as? [String: Any] else {
            throw MessageParseError.invalidJSON
        }

        for (key, value) in patchDict {
            dict[key] = value
        }

        let mergedData = try JSONSerialization.data(withJSONObject: dict)
        return try decoder.decode(T.self, from: mergedData)
    }
}

private struct TypeContainer: Decodable {
    let type: MessageType
}

// MARK: - Usage: Service + SwiftUI

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

        // Partial arrives — same wrapper reference, .value updated via dict merge
        try service.onReceived("""
        { "type": "user", "age": 31 }
        """.data(using: .utf8)!)

        // Same reference, new value — SwiftUI auto-refreshes
        print("\(userRef.value.name), age \(userRef.value.age)")
        // -> "John, age 31"
    } catch {
        print("Error: \(error)")
    }
}

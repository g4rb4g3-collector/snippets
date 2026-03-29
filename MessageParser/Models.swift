import Foundation
import Observation

// MARK: - Message Type

enum MessageType: String {
    case user
    case address
    case contactInfo
}

// MARK: - Models

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

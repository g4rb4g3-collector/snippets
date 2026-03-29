import Foundation
import Observation

// MARK: - Errors

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

// MARK: - Message Parser

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
        let messageType = try extractType(from: data)

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

    /// First pass: scan tokens to find "type" value.
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

    /// Second pass: tokenize and apply each field directly to the object.
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
                    guard let valueToken = tokenizer.nextToken() else { return }
                    _ = setter.apply(target, tokenToAny(valueToken))
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

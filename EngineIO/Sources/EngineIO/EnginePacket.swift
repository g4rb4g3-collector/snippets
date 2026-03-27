import Foundation

// MARK: - Engine.IO v4 Packet Types

/// Engine.IO packet types as defined by the protocol specification.
public enum EnginePacketType: Int, Sendable {
    case open = 0
    case close = 1
    case ping = 2
    case pong = 3
    case message = 4
    case upgrade = 5
    case noop = 6
}

/// Represents a single engine.io packet.
public enum EnginePacket: Sendable, Equatable {
    case open(HandshakeData)
    case close
    case ping(String?)
    case pong(String?)
    case message(EnginePayload)
    case upgrade
    case noop

    public var type: EnginePacketType {
        switch self {
        case .open: return .open
        case .close: return .close
        case .ping: return .ping
        case .pong: return .pong
        case .message: return .message
        case .upgrade: return .upgrade
        case .noop: return .noop
        }
    }
}

/// Message payload — either text or binary.
public enum EnginePayload: Sendable, Equatable {
    case text(String)
    case binary(Data)
}

/// Server handshake data sent in the `open` packet.
public struct HandshakeData: Sendable, Equatable, Decodable {
    public let sid: String
    public let upgrades: [String]
    public let pingInterval: Int
    public let pingTimeout: Int
    public let maxPayload: Int?
}

// MARK: - Encoding

extension EnginePacket {

    /// Encode a packet to a string for text-based transports (polling GET/POST, WebSocket text frames).
    public func encodeToString() -> String {
        let typeChar = String(type.rawValue)
        switch self {
        case .open(let data):
            let encoder = JSONEncoder()
            if let json = try? encoder.encode(CodableHandshake(data)),
               let str = String(data: json, encoding: .utf8) {
                return typeChar + str
            }
            return typeChar
        case .close, .upgrade, .noop:
            return typeChar
        case .ping(let payload):
            return typeChar + (payload ?? "")
        case .pong(let payload):
            return typeChar + (payload ?? "")
        case .message(.text(let text)):
            return typeChar + text
        case .message(.binary(let data)):
            return "b" + data.base64EncodedString()
        }
    }
}

// MARK: - Decoding

extension EnginePacket {

    /// Decode a single packet from a string (polling or WebSocket text frame).
    public static func decode(from string: String) throws -> EnginePacket {
        guard let first = string.first else {
            throw EngineIOError.invalidPacket("Empty packet string")
        }

        // Binary packet encoded as base64 with 'b' prefix
        if first == "b" {
            let base64 = String(string.dropFirst())
            guard let data = Data(base64Encoded: base64) else {
                throw EngineIOError.invalidPacket("Invalid base64 in binary packet")
            }
            return .message(.binary(data))
        }

        guard let typeInt = Int(String(first)),
              let type = EnginePacketType(rawValue: typeInt) else {
            throw EngineIOError.invalidPacket("Unknown packet type: \(first)")
        }

        let payload = String(string.dropFirst())

        switch type {
        case .open:
            guard let jsonData = payload.data(using: .utf8) else {
                throw EngineIOError.invalidPacket("Invalid open packet encoding")
            }
            let handshake = try JSONDecoder().decode(HandshakeData.self, from: jsonData)
            return .open(handshake)
        case .close:
            return .close
        case .ping:
            return .ping(payload.isEmpty ? nil : payload)
        case .pong:
            return .pong(payload.isEmpty ? nil : payload)
        case .message:
            return .message(.text(payload))
        case .upgrade:
            return .upgrade
        case .noop:
            return .noop
        }
    }

    /// Decode a binary WebSocket frame as a binary message packet.
    public static func decode(from data: Data) -> EnginePacket {
        return .message(.binary(data))
    }

    /// Decode a polling payload (multiple packets separated by \x1e record separator).
    public static func decodePayload(from string: String) throws -> [EnginePacket] {
        let parts = string.components(separatedBy: "\u{1e}")
        return try parts.map { try decode(from: $0) }
    }

    /// Encode multiple packets into a polling payload string.
    public static func encodePayload(_ packets: [EnginePacket]) -> String {
        return packets.map { $0.encodeToString() }.joined(separator: "\u{1e}")
    }
}

// MARK: - Internal helpers

private struct CodableHandshake: Encodable {
    let sid: String
    let upgrades: [String]
    let pingInterval: Int
    let pingTimeout: Int
    let maxPayload: Int?

    init(_ h: HandshakeData) {
        self.sid = h.sid
        self.upgrades = h.upgrades
        self.pingInterval = h.pingInterval
        self.pingTimeout = h.pingTimeout
        self.maxPayload = h.maxPayload
    }
}

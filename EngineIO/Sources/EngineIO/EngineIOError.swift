import Foundation

/// Errors that can occur during engine.io communication.
public enum EngineIOError: Error, LocalizedError, Sendable {
    case invalidPacket(String)
    case invalidURL(String)
    case handshakeFailed(String)
    case transportError(String)
    case heartbeatTimeout
    case serverClosedConnection
    case connectionClosed
    case upgradeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPacket(let msg): return "Invalid packet: \(msg)"
        case .invalidURL(let msg): return "Invalid URL: \(msg)"
        case .handshakeFailed(let msg): return "Handshake failed: \(msg)"
        case .transportError(let msg): return "Transport error: \(msg)"
        case .heartbeatTimeout: return "Heartbeat timeout"
        case .serverClosedConnection: return "Server closed connection"
        case .connectionClosed: return "Connection closed"
        case .upgradeFailed(let msg): return "Upgrade failed: \(msg)"
        }
    }
}

import Foundation

/// Transport type used by the engine.io connection.
public enum TransportType: String, Sendable {
    case polling
    case websocket
}

/// Delegate protocol for transports to communicate with the engine.
protocol TransportDelegate: AnyObject {
    func transport(_ transport: Transport, didReceivePacket packet: EnginePacket)
    func transport(_ transport: Transport, didReceiveError error: Error)
    func transportDidOpen(_ transport: Transport)
    func transportDidClose(_ transport: Transport)
}

/// Base protocol for engine.io transports.
protocol Transport: AnyObject {
    var type: TransportType { get }
    var delegate: TransportDelegate? { get set }
    var isOpen: Bool { get }

    func open()
    func close()
    func send(packets: [EnginePacket])
    func pause()
}

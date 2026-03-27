import Foundation

// MARK: - Connection State

/// The current state of the engine.io connection.
public enum EngineIOState: Sendable {
    case disconnected
    case connecting
    case connected
    case upgrading
    case disconnecting
}

// MARK: - Delegate

/// Delegate protocol for receiving engine.io events.
public protocol EngineIOClientDelegate: AnyObject {
    func engineDidOpen(_ client: EngineIOClient, handshake: HandshakeData)
    func engineDidClose(_ client: EngineIOClient, reason: String)
    func engineDidReceiveMessage(_ client: EngineIOClient, text: String)
    func engineDidReceiveBinaryMessage(_ client: EngineIOClient, data: Data)
    func engineDidError(_ client: EngineIOClient, error: Error)
    func engineDidUpgrade(_ client: EngineIOClient, from: TransportType, to: TransportType)
}

// Default implementations so delegates can opt-in to what they care about
public extension EngineIOClientDelegate {
    func engineDidReceiveBinaryMessage(_ client: EngineIOClient, data: Data) {}
    func engineDidError(_ client: EngineIOClient, error: Error) {}
    func engineDidUpgrade(_ client: EngineIOClient, from: TransportType, to: TransportType) {}
}

// MARK: - Configuration

/// Configuration options for the engine.io client.
public struct EngineIOConfiguration: Sendable {
    /// Base URL of the engine.io server (e.g., "http://localhost:3000")
    public var url: String

    /// Path on the server (default: "/engine.io/")
    public var path: String

    /// Extra HTTP headers sent with every request
    public var extraHeaders: [String: String]

    /// Initial transport to use
    public var transports: [TransportType]

    /// Whether to attempt upgrading from polling to websocket
    public var upgrade: Bool

    /// Custom URLSession configuration
    public var sessionConfiguration: URLSessionConfiguration

    public init(
        url: String,
        path: String = "/engine.io/",
        extraHeaders: [String: String] = [:],
        transports: [TransportType] = [.polling, .websocket],
        upgrade: Bool = true,
        sessionConfiguration: URLSessionConfiguration = .default
    ) {
        self.url = url
        self.path = path
        self.extraHeaders = extraHeaders
        self.transports = transports
        self.upgrade = upgrade
        self.sessionConfiguration = sessionConfiguration
    }
}

// MARK: - Client

/// Engine.IO v4 client implementation.
///
/// Supports HTTP long-polling and WebSocket transports with automatic upgrade.
/// Uses native `URLSession` and `URLSessionWebSocketTask` — no third-party dependencies.
///
/// Usage:
/// ```swift
/// let config = EngineIOConfiguration(url: "http://localhost:3000")
/// let client = EngineIOClient(config: config)
/// client.delegate = self
/// client.connect()
///
/// // Send a text message
/// client.send(text: "hello")
///
/// // Send binary data
/// client.send(data: someData)
///
/// // Disconnect
/// client.disconnect()
/// ```
public final class EngineIOClient: NSObject {
    public weak var delegate: EngineIOClientDelegate?
    public private(set) var state: EngineIOState = .disconnected
    public private(set) var sid: String?

    private let config: EngineIOConfiguration
    private var session: URLSession!
    private var currentTransport: Transport?
    private var probingTransport: Transport?
    private var handshake: HandshakeData?
    private var pingTimeoutTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "io.engine.client")

    public init(config: EngineIOConfiguration) {
        self.config = config
        super.init()
        self.session = URLSession(configuration: config.sessionConfiguration, delegate: nil, delegateQueue: nil)
    }

    deinit {
        pingTimeoutTimer?.cancel()
    }

    // MARK: - Public API

    /// Open the connection to the engine.io server.
    public func connect() {
        guard state == .disconnected else { return }
        state = .connecting

        let initialTransport = config.transports.first ?? .polling

        if initialTransport == .websocket {
            connectWithWebSocket()
        } else {
            connectWithPolling()
        }
    }

    /// Disconnect from the server.
    public func disconnect() {
        guard state == .connected || state == .connecting || state == .upgrading else { return }
        state = .disconnecting
        cancelPingTimeout()
        currentTransport?.close()
    }

    /// Send a text message.
    public func send(text: String) {
        send(packet: .message(.text(text)))
    }

    /// Send binary data.
    public func send(data: Data) {
        send(packet: .message(.binary(data)))
    }

    /// Send a raw packet.
    public func send(packet: EnginePacket) {
        guard state == .connected || state == .upgrading else { return }
        currentTransport?.send(packets: [packet])
    }

    // MARK: - Connection setup

    private func connectWithPolling() {
        guard let url = buildBaseURL() else {
            delegate?.engineDidError(self, error: EngineIOError.invalidURL(config.url))
            state = .disconnected
            return
        }

        let transport = PollingTransport(url: url, session: session, extraHeaders: config.extraHeaders)
        transport.delegate = self
        currentTransport = transport
        transport.open()
    }

    private func connectWithWebSocket() {
        guard let url = buildBaseURL() else {
            delegate?.engineDidError(self, error: EngineIOError.invalidURL(config.url))
            state = .disconnected
            return
        }

        let transport = WebSocketTransport(url: url, session: session, extraHeaders: config.extraHeaders)
        transport.delegate = self
        currentTransport = transport
        transport.open()
    }

    // MARK: - Upgrade (polling -> websocket)

    private func attemptUpgrade() {
        guard config.upgrade,
              let handshake,
              handshake.upgrades.contains("websocket"),
              currentTransport?.type == .polling else { return }

        guard let url = buildBaseURL() else { return }

        state = .upgrading

        let wsTransport = WebSocketTransport(url: url, session: session, sid: sid, extraHeaders: config.extraHeaders)
        wsTransport.delegate = self
        probingTransport = wsTransport
        wsTransport.open()

        // Send probe ping over websocket
        wsTransport.send(packets: [.ping("probe")])
    }

    private func completeUpgrade() {
        guard let wsTransport = probingTransport else { return }

        // Pause polling, switch transport
        currentTransport?.pause()
        let oldType = currentTransport?.type ?? .polling

        currentTransport = wsTransport
        probingTransport = nil
        state = .connected

        // Send upgrade packet to finalize
        wsTransport.send(packets: [.upgrade])

        delegate?.engineDidUpgrade(self, from: oldType, to: .websocket)
    }

    // MARK: - Heartbeat

    private func resetPingTimeout() {
        cancelPingTimeout()

        guard let handshake else { return }

        let timeout = TimeInterval(handshake.pingInterval + handshake.pingTimeout) / 1000.0
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.delegate?.engineDidError(self, error: EngineIOError.heartbeatTimeout)
            self.onClose(reason: "heartbeat timeout")
        }
        timer.resume()
        pingTimeoutTimer = timer
    }

    private func cancelPingTimeout() {
        pingTimeoutTimer?.cancel()
        pingTimeoutTimer = nil
    }

    // MARK: - Packet handling

    private func handlePacket(_ packet: EnginePacket, from transport: Transport) {
        switch packet {
        case .open(let data):
            handleOpen(data, from: transport)

        case .close:
            onClose(reason: "server close")

        case .ping(let payload):
            // Server-initiated ping (v4): respond with pong
            currentTransport?.send(packets: [.pong(payload)])
            resetPingTimeout()

        case .pong(let payload):
            // Pong received — could be a probe response during upgrade
            if transport === probingTransport, payload == "probe" {
                completeUpgrade()
            }

        case .message(.text(let text)):
            delegate?.engineDidReceiveMessage(self, text: text)

        case .message(.binary(let data)):
            delegate?.engineDidReceiveBinaryMessage(self, data: data)

        case .noop:
            break

        case .upgrade:
            break
        }
    }

    private func handleOpen(_ data: HandshakeData, from transport: Transport) {
        handshake = data
        sid = data.sid

        // If polling, set the sid on the transport
        if let polling = transport as? PollingTransport {
            polling.setSid(data.sid)
        }

        state = .connected
        delegate?.engineDidOpen(self, handshake: data)
        resetPingTimeout()

        // Attempt upgrade if configured
        attemptUpgrade()
    }

    private func onClose(reason: String) {
        guard state != .disconnected else { return }
        state = .disconnected
        cancelPingTimeout()
        currentTransport = nil
        probingTransport = nil
        sid = nil
        handshake = nil
        delegate?.engineDidClose(self, reason: reason)
    }

    // MARK: - URL helpers

    private func buildBaseURL() -> URL? {
        var urlString = config.url

        // Ensure path
        let path = config.path.hasSuffix("/") ? config.path : config.path + "/"
        if !urlString.hasSuffix("/") {
            urlString += path
        } else {
            urlString += path.dropFirst()
        }

        guard var components = URLComponents(string: urlString) else { return nil }

        components.queryItems = [
            URLQueryItem(name: "EIO", value: "4"),
            URLQueryItem(name: "transport", value: "polling")
        ]

        return components.url
    }
}

// MARK: - TransportDelegate

extension EngineIOClient: TransportDelegate {
    func transport(_ transport: Transport, didReceivePacket packet: EnginePacket) {
        queue.async { [weak self] in
            self?.handlePacket(packet, from: transport)
        }
    }

    func transport(_ transport: Transport, didReceiveError error: Error) {
        queue.async { [weak self] in
            guard let self else { return }

            // If the probing transport fails, cancel upgrade silently
            if transport === self.probingTransport {
                self.probingTransport = nil
                self.state = .connected
                self.delegate?.engineDidError(self, error: EngineIOError.upgradeFailed(error.localizedDescription))
                return
            }

            self.delegate?.engineDidError(self, error: error)
        }
    }

    func transportDidOpen(_ transport: Transport) {
        // WebSocket transport opened — if it's the main transport (websocket-only mode),
        // we don't need to do anything special; the handshake open packet will arrive.
    }

    func transportDidClose(_ transport: Transport) {
        queue.async { [weak self] in
            guard let self else { return }

            if transport === self.probingTransport {
                self.probingTransport = nil
                self.state = .connected
                return
            }

            self.onClose(reason: "transport close")
        }
    }
}

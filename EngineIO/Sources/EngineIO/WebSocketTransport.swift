import Foundation

/// WebSocket transport for engine.io v4, using native URLSessionWebSocketTask (iOS 13+).
final class WebSocketTransport: NSObject, Transport {
    let type: TransportType = .websocket
    weak var delegate: TransportDelegate?

    private let baseURL: URL
    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var extraHeaders: [String: String]
    private var sid: String?
    private(set) var isOpen = false
    private let queue = DispatchQueue(label: "io.engine.websocket")

    init(url: URL, session: URLSession, sid: String? = nil, extraHeaders: [String: String] = [:]) {
        self.baseURL = url
        self.session = session
        self.sid = sid
        self.extraHeaders = extraHeaders
    }

    func open() {
        guard let url = makeURL() else {
            delegate?.transport(self, didReceiveError: EngineIOError.invalidURL("Failed to construct WebSocket URL"))
            return
        }

        var request = URLRequest(url: url)
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        isOpen = true
        delegate?.transportDidOpen(self)
        receiveMessage()
    }

    func close() {
        isOpen = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        delegate?.transportDidClose(self)
    }

    func pause() {
        // WebSocket transport doesn't pause in the same way as polling
    }

    func send(packets: [EnginePacket]) {
        for packet in packets {
            sendPacket(packet)
        }
    }

    // MARK: - Send

    private func sendPacket(_ packet: EnginePacket) {
        guard isOpen, let task = webSocketTask else { return }

        let wsMessage: URLSessionWebSocketTask.Message

        // Binary message payloads go as binary frames, everything else as text
        if case .message(.binary(let data)) = packet {
            wsMessage = .data(data)
        } else {
            wsMessage = .string(packet.encodeToString())
        }

        task.send(wsMessage) { [weak self] error in
            if let error, let self {
                self.delegate?.transport(self, didReceiveError: EngineIOError.transportError(error.localizedDescription))
            }
        }
    }

    // MARK: - Receive

    private func receiveMessage() {
        guard isOpen, let task = webSocketTask else { return }

        task.receive { [weak self] result in
            guard let self, self.isOpen else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    do {
                        let packet = try EnginePacket.decode(from: text)
                        self.delegate?.transport(self, didReceivePacket: packet)
                    } catch {
                        self.delegate?.transport(self, didReceiveError: error)
                    }
                case .data(let data):
                    let packet = EnginePacket.decode(from: data)
                    self.delegate?.transport(self, didReceivePacket: packet)
                @unknown default:
                    break
                }

                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                guard self.isOpen else { return }
                self.isOpen = false
                self.delegate?.transport(self, didReceiveError: EngineIOError.transportError(error.localizedDescription))
                self.delegate?.transportDidClose(self)
            }
        }
    }

    // MARK: - URL construction

    private func makeURL() -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)

        // Convert http(s) to ws(s)
        if components?.scheme == "https" {
            components?.scheme = "wss"
        } else {
            components?.scheme = "ws"
        }

        var queryItems = components?.queryItems ?? []

        if !queryItems.contains(where: { $0.name == "EIO" }) {
            queryItems.append(URLQueryItem(name: "EIO", value: "4"))
        }

        // Replace transport param
        queryItems.removeAll { $0.name == "transport" }
        queryItems.append(URLQueryItem(name: "transport", value: "websocket"))

        if let sid, !queryItems.contains(where: { $0.name == "sid" }) {
            queryItems.append(URLQueryItem(name: "sid", value: sid))
        }

        components?.queryItems = queryItems
        return components?.url
    }
}

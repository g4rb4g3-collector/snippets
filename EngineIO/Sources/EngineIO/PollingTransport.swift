import Foundation

/// HTTP long-polling transport for engine.io v4.
final class PollingTransport: Transport {
    let type: TransportType = .polling
    weak var delegate: TransportDelegate?

    private let baseURL: URL
    private let session: URLSession
    private var sid: String?
    private var extraHeaders: [String: String]
    private(set) var isOpen = false
    private var isPaused = false
    private var isPolling = false
    private var sendQueue: [EnginePacket] = []
    private var isSending = false
    private let queue = DispatchQueue(label: "io.engine.polling")

    init(url: URL, session: URLSession, sid: String? = nil, extraHeaders: [String: String] = [:]) {
        self.baseURL = url
        self.session = session
        self.sid = sid
        self.extraHeaders = extraHeaders
    }

    func setSid(_ sid: String) {
        self.sid = sid
    }

    func open() {
        isOpen = true
        isPaused = false
        poll()
    }

    func close() {
        send(packets: [.close])
        doClose()
    }

    func pause() {
        isPaused = true
    }

    func send(packets: [EnginePacket]) {
        queue.async { [weak self] in
            guard let self, self.isOpen else { return }
            self.sendQueue.append(contentsOf: packets)
            self.flush()
        }
    }

    // MARK: - Polling

    private func poll() {
        queue.async { [weak self] in
            guard let self, self.isOpen, !self.isPaused else { return }
            guard !self.isPolling else { return }
            self.isPolling = true
            self.doPoll()
        }
    }

    private func doPoll() {
        guard let url = makeURL() else {
            delegate?.transport(self, didReceiveError: EngineIOError.invalidURL("Failed to construct polling URL"))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            self.queue.async {
                self.isPolling = false

                if let error {
                    self.delegate?.transport(self, didReceiveError: EngineIOError.transportError(error.localizedDescription))
                    return
                }

                guard let data, let body = String(data: data, encoding: .utf8), !body.isEmpty else {
                    self.delegate?.transport(self, didReceiveError: EngineIOError.transportError("Empty polling response"))
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    self.delegate?.transport(self, didReceiveError: EngineIOError.transportError("HTTP \(httpResponse.statusCode)"))
                    return
                }

                do {
                    let packets = try EnginePacket.decodePayload(from: body)
                    for packet in packets {
                        self.delegate?.transport(self, didReceivePacket: packet)
                    }
                } catch {
                    self.delegate?.transport(self, didReceiveError: error)
                }

                // Continue polling
                if self.isOpen && !self.isPaused {
                    self.poll()
                }
            }
        }
        task.resume()
    }

    // MARK: - Sending

    private func flush() {
        guard !sendQueue.isEmpty, !isSending else { return }
        isSending = true

        let packets = sendQueue
        sendQueue.removeAll()

        guard let url = makeURL() else {
            isSending = false
            delegate?.transport(self, didReceiveError: EngineIOError.invalidURL("Failed to construct polling URL"))
            return
        }

        let payload = EnginePacket.encodePayload(packets)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = payload.data(using: .utf8)

        let task = session.dataTask(with: request) { [weak self] _, response, error in
            guard let self else { return }

            self.queue.async {
                self.isSending = false

                if let error {
                    self.delegate?.transport(self, didReceiveError: EngineIOError.transportError(error.localizedDescription))
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    self.delegate?.transport(self, didReceiveError: EngineIOError.transportError("POST HTTP \(httpResponse.statusCode)"))
                    return
                }

                // Flush remaining if any
                if !self.sendQueue.isEmpty {
                    self.flush()
                }
            }
        }
        task.resume()
    }

    // MARK: - URL construction

    private func makeURL() -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []

        // Ensure EIO and transport are set
        if !queryItems.contains(where: { $0.name == "EIO" }) {
            queryItems.append(URLQueryItem(name: "EIO", value: "4"))
        }
        if !queryItems.contains(where: { $0.name == "transport" }) {
            queryItems.append(URLQueryItem(name: "transport", value: "polling"))
        }
        if let sid, !queryItems.contains(where: { $0.name == "sid" }) {
            queryItems.append(URLQueryItem(name: "sid", value: sid))
        }

        // Cache-bust for HTTP polling
        queryItems.append(URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970 * 1000))))

        components?.queryItems = queryItems
        return components?.url
    }

    private func doClose() {
        isOpen = false
        isPaused = true
        delegate?.transportDidClose(self)
    }
}

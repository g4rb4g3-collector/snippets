// Engine.IO v4 Client for Swift/iOS
//
// A standalone implementation of the engine.io protocol (v4, EIO=4)
// using native URLSession — no third-party dependencies required.
//
// Supports:
// - HTTP long-polling transport
// - WebSocket transport (via URLSessionWebSocketTask, iOS 13+)
// - Automatic upgrade from polling to WebSocket
// - Server-driven heartbeat (ping/pong)
// - Binary message support
// - Record-separator payload encoding (\x1e) for polling
//
// Protocol reference: https://socket.io/docs/v4/engine-io-protocol/

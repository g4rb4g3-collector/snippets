import XCTest
@testable import EngineIO

final class EnginePacketTests: XCTestCase {

    // MARK: - Decoding

    func testDecodeOpenPacket() throws {
        let raw = """
        0{"sid":"abc123","upgrades":["websocket"],"pingInterval":25000,"pingTimeout":20000,"maxPayload":1000000}
        """
        let packet = try EnginePacket.decode(from: raw)

        guard case .open(let handshake) = packet else {
            XCTFail("Expected open packet")
            return
        }

        XCTAssertEqual(handshake.sid, "abc123")
        XCTAssertEqual(handshake.upgrades, ["websocket"])
        XCTAssertEqual(handshake.pingInterval, 25000)
        XCTAssertEqual(handshake.pingTimeout, 20000)
        XCTAssertEqual(handshake.maxPayload, 1000000)
    }

    func testDecodeClosePacket() throws {
        let packet = try EnginePacket.decode(from: "1")
        guard case .close = packet else {
            XCTFail("Expected close packet")
            return
        }
    }

    func testDecodePingPacket() throws {
        let packet = try EnginePacket.decode(from: "2")
        guard case .ping(nil) = packet else {
            XCTFail("Expected ping packet with nil payload")
            return
        }
    }

    func testDecodePingWithProbe() throws {
        let packet = try EnginePacket.decode(from: "2probe")
        guard case .ping(let payload) = packet else {
            XCTFail("Expected ping packet")
            return
        }
        XCTAssertEqual(payload, "probe")
    }

    func testDecodePongPacket() throws {
        let packet = try EnginePacket.decode(from: "3probe")
        guard case .pong(let payload) = packet else {
            XCTFail("Expected pong packet")
            return
        }
        XCTAssertEqual(payload, "probe")
    }

    func testDecodeMessagePacket() throws {
        let packet = try EnginePacket.decode(from: "4hello world")
        guard case .message(.text(let text)) = packet else {
            XCTFail("Expected text message packet")
            return
        }
        XCTAssertEqual(text, "hello world")
    }

    func testDecodeUpgradePacket() throws {
        let packet = try EnginePacket.decode(from: "5")
        guard case .upgrade = packet else {
            XCTFail("Expected upgrade packet")
            return
        }
    }

    func testDecodeNoopPacket() throws {
        let packet = try EnginePacket.decode(from: "6")
        guard case .noop = packet else {
            XCTFail("Expected noop packet")
            return
        }
    }

    func testDecodeBinaryPacket() throws {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let base64 = data.base64EncodedString() // "AQIDBA=="
        let packet = try EnginePacket.decode(from: "b\(base64)")
        guard case .message(.binary(let decoded)) = packet else {
            XCTFail("Expected binary message packet")
            return
        }
        XCTAssertEqual(decoded, data)
    }

    func testDecodeEmptyPacketThrows() {
        XCTAssertThrowsError(try EnginePacket.decode(from: ""))
    }

    func testDecodeInvalidTypeThrows() {
        XCTAssertThrowsError(try EnginePacket.decode(from: "9invalid"))
    }

    // MARK: - Encoding

    func testEncodeClosePacket() {
        XCTAssertEqual(EnginePacket.close.encodeToString(), "1")
    }

    func testEncodePingPacket() {
        XCTAssertEqual(EnginePacket.ping(nil).encodeToString(), "2")
        XCTAssertEqual(EnginePacket.ping("probe").encodeToString(), "2probe")
    }

    func testEncodePongPacket() {
        XCTAssertEqual(EnginePacket.pong(nil).encodeToString(), "3")
        XCTAssertEqual(EnginePacket.pong("probe").encodeToString(), "3probe")
    }

    func testEncodeMessagePacket() {
        XCTAssertEqual(EnginePacket.message(.text("hello")).encodeToString(), "4hello")
    }

    func testEncodeBinaryMessage() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let encoded = EnginePacket.message(.binary(data)).encodeToString()
        XCTAssertEqual(encoded, "bAQIDBA==")
    }

    func testEncodeUpgradePacket() {
        XCTAssertEqual(EnginePacket.upgrade.encodeToString(), "5")
    }

    func testEncodeNoopPacket() {
        XCTAssertEqual(EnginePacket.noop.encodeToString(), "6")
    }

    // MARK: - Payload encoding/decoding (record separator)

    func testDecodePayload() throws {
        let payload = "4hello\u{1e}2\u{1e}4world"
        let packets = try EnginePacket.decodePayload(from: payload)

        XCTAssertEqual(packets.count, 3)

        guard case .message(.text("hello")) = packets[0] else {
            XCTFail("Expected message 'hello'")
            return
        }
        guard case .ping(nil) = packets[1] else {
            XCTFail("Expected ping")
            return
        }
        guard case .message(.text("world")) = packets[2] else {
            XCTFail("Expected message 'world'")
            return
        }
    }

    func testDecodePayloadWithBinary() throws {
        let payload = "4hello\u{1e}bAQIDBA=="
        let packets = try EnginePacket.decodePayload(from: payload)

        XCTAssertEqual(packets.count, 2)
        guard case .message(.text("hello")) = packets[0] else {
            XCTFail("Expected text message")
            return
        }
        guard case .message(.binary(let data)) = packets[1] else {
            XCTFail("Expected binary message")
            return
        }
        XCTAssertEqual(data, Data([0x01, 0x02, 0x03, 0x04]))
    }

    func testEncodePayload() {
        let packets: [EnginePacket] = [
            .message(.text("hello")),
            .ping(nil),
            .message(.text("world"))
        ]
        let payload = EnginePacket.encodePayload(packets)
        XCTAssertEqual(payload, "4hello\u{1e}2\u{1e}4world")
    }

    // MARK: - Roundtrip

    func testRoundtripTextMessage() throws {
        let original = EnginePacket.message(.text("test message"))
        let encoded = original.encodeToString()
        let decoded = try EnginePacket.decode(from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testRoundtripBinaryMessage() throws {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let original = EnginePacket.message(.binary(data))
        let encoded = original.encodeToString()
        let decoded = try EnginePacket.decode(from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testRoundtripPayload() throws {
        let original: [EnginePacket] = [
            .message(.text("one")),
            .message(.binary(Data([0xFF]))),
            .pong(nil),
            .message(.text("two"))
        ]
        let payload = EnginePacket.encodePayload(original)
        let decoded = try EnginePacket.decodePayload(from: payload)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - HandshakeData

    func testHandshakeWithoutMaxPayload() throws {
        let raw = """
        0{"sid":"xyz","upgrades":[],"pingInterval":10000,"pingTimeout":5000}
        """
        let packet = try EnginePacket.decode(from: raw)
        guard case .open(let h) = packet else {
            XCTFail("Expected open")
            return
        }
        XCTAssertEqual(h.sid, "xyz")
        XCTAssertEqual(h.upgrades, [])
        XCTAssertNil(h.maxPayload)
    }

    // MARK: - Packet type values

    func testPacketTypeRawValues() {
        XCTAssertEqual(EnginePacketType.open.rawValue, 0)
        XCTAssertEqual(EnginePacketType.close.rawValue, 1)
        XCTAssertEqual(EnginePacketType.ping.rawValue, 2)
        XCTAssertEqual(EnginePacketType.pong.rawValue, 3)
        XCTAssertEqual(EnginePacketType.message.rawValue, 4)
        XCTAssertEqual(EnginePacketType.upgrade.rawValue, 5)
        XCTAssertEqual(EnginePacketType.noop.rawValue, 6)
    }
}

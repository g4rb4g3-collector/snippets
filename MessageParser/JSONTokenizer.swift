import Foundation

/// JSON token types produced by the tokenizer.
enum JSONToken {
    case objectStart          // {
    case objectEnd            // }
    case arrayStart           // [
    case arrayEnd             // ]
    case comma                // ,
    case colon                // :
    case string(String)       // "..."
    case number(Double)       // 123, 1.5
    case bool(Bool)           // true, false
    case null                 // null
}

/// Streaming JSON tokenizer that reads byte-by-byte.
struct JSONTokenizer {
    private let data: [UInt8]
    private var pos: Int = 0

    init(_ data: Data) {
        self.data = [UInt8](data)
    }

    mutating func nextToken() -> JSONToken? {
        skipWhitespace()
        guard pos < data.count else { return nil }

        switch data[pos] {
        case UInt8(ascii: "{"):
            pos += 1; return .objectStart
        case UInt8(ascii: "}"):
            pos += 1; return .objectEnd
        case UInt8(ascii: "["):
            pos += 1; return .arrayStart
        case UInt8(ascii: "]"):
            pos += 1; return .arrayEnd
        case UInt8(ascii: ","):
            pos += 1; return .comma
        case UInt8(ascii: ":"):
            pos += 1; return .colon
        case UInt8(ascii: "\""):
            return .string(readString())
        case UInt8(ascii: "t"):
            pos += 4; return .bool(true)
        case UInt8(ascii: "f"):
            pos += 5; return .bool(false)
        case UInt8(ascii: "n"):
            pos += 4; return .null
        default:
            return .number(readNumber())
        }
    }

    /// Skip an entire JSON value (object, array, string, or primitive).
    mutating func skipValue() {
        skipWhitespace()
        guard pos < data.count else { return }
        switch data[pos] {
        case UInt8(ascii: "{"):
            skipContainer(open: UInt8(ascii: "{"), close: UInt8(ascii: "}"))
        case UInt8(ascii: "["):
            skipContainer(open: UInt8(ascii: "["), close: UInt8(ascii: "]"))
        case UInt8(ascii: "\""):
            _ = readString()
        default:
            _ = nextToken()
        }
    }

    // MARK: - Private

    private mutating func skipWhitespace() {
        while pos < data.count {
            switch data[pos] {
            case UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\n"), UInt8(ascii: "\r"):
                pos += 1
            default:
                return
            }
        }
    }

    private mutating func readString() -> String {
        pos += 1 // skip opening quote
        var start = pos
        var result = ""
        while pos < data.count && data[pos] != UInt8(ascii: "\"") {
            if data[pos] == UInt8(ascii: "\\") {
                result += String(bytes: data[start..<pos], encoding: .utf8) ?? ""
                pos += 1 // skip backslash
                switch data[pos] {
                case UInt8(ascii: "\""): result += "\""
                case UInt8(ascii: "\\"): result += "\\"
                case UInt8(ascii: "n"):  result += "\n"
                case UInt8(ascii: "t"):  result += "\t"
                case UInt8(ascii: "r"):  result += "\r"
                default: result.append(Character(UnicodeScalar(data[pos])))
                }
                pos += 1
                start = pos
            } else {
                pos += 1
            }
        }
        result += String(bytes: data[start..<pos], encoding: .utf8) ?? ""
        pos += 1 // skip closing quote
        return result
    }

    private mutating func readNumber() -> Double {
        let start = pos
        while pos < data.count {
            let c = data[pos]
            if c == UInt8(ascii: ",") || c == UInt8(ascii: "}") || c == UInt8(ascii: "]")
                || c == UInt8(ascii: " ") || c == UInt8(ascii: "\n") || c == UInt8(ascii: "\r") || c == UInt8(ascii: "\t") {
                break
            }
            pos += 1
        }
        let str = String(bytes: data[start..<pos], encoding: .utf8) ?? "0"
        return Double(str) ?? 0
    }

    private mutating func skipContainer(open: UInt8, close: UInt8) {
        var depth = 0
        var inString = false
        while pos < data.count {
            let c = data[pos]
            if inString {
                if c == UInt8(ascii: "\\") { pos += 1 }
                else if c == UInt8(ascii: "\"") { inString = false }
            } else {
                if c == UInt8(ascii: "\"") { inString = true }
                else if c == open { depth += 1 }
                else if c == close { depth -= 1; if depth == 0 { pos += 1; return } }
            }
            pos += 1
        }
    }
}

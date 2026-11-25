import Foundation

/// Turns a stream of BLE notification chunks into complete messages.
///
/// The PowerBox protocol is not documented, so this handles the common
/// shapes of serial-over-BLE devices:
///  - `{...}` JSON objects, with or without a line terminator, possibly split
///    over several notifications (the default BLE payload is only 20 bytes)
///  - text lines ending in `\n`, `\r` or `\r\n`
///  - anything else: the caller calls `flush()` after a short quiet period,
///    which treats whatever is buffered as one message
struct StreamAssembler {
    static let maxBuffer = 2048

    private(set) var buffer = ""

    mutating func feed(_ text: String) -> [String] {
        buffer += text
        var messages: [String] = []

        while true {
            dropLeadingWhitespace()
            guard let first = buffer.first else { break }

            if first == "{" {
                guard let close = buffer.firstIndex(of: "}") else { break }
                // A '{' before the closing '}' means an earlier fragment got
                // lost. Resync on the last '{' before the '}'.
                let head = buffer[..<close]
                let start = head.lastIndex(of: "{") ?? buffer.startIndex
                messages.append(String(buffer[start...close]))
                buffer = String(buffer[buffer.index(after: close)...])
                continue
            }

            if let newline = buffer.firstIndex(where: { $0 == "\n" || $0 == "\r" || $0 == "\r\n" }) {
                let line = String(buffer[..<newline]).trimmingCharacters(in: .whitespaces)
                if !line.isEmpty {
                    messages.append(line)
                }
                buffer = String(buffer[buffer.index(after: newline)...])
                continue
            }

            // A JSON object may start in the middle of non-JSON text.
            if let brace = buffer.firstIndex(of: "{"), brace != buffer.startIndex {
                let before = String(buffer[..<brace]).trimmingCharacters(in: .whitespaces)
                if !before.isEmpty {
                    messages.append(before)
                }
                buffer = String(buffer[brace...])
                continue
            }
            break
        }

        if buffer.count > Self.maxBuffer {
            buffer = ""
        }
        return messages
    }

    /// Emits whatever is buffered as one message (used after a quiet period).
    mutating func flush() -> String? {
        let rest = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""
        return rest.isEmpty ? nil : rest
    }

    mutating func reset() {
        buffer = ""
    }

    private mutating func dropLeadingWhitespace() {
        while let c = buffer.first, c.isWhitespace || c.isNewline {
            buffer.removeFirst()
        }
    }
}

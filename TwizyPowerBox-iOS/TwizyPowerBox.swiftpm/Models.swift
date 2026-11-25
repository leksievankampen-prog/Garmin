import CoreBluetooth
import Foundation

struct DiscoveredDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    var name: String
    var rssi: Int
    var serviceUUIDs: [CBUUID]
    var lastUpdate: Date

    var isLikelyPowerBox: Bool {
        PowerBoxHints.isLikely(name: name, services: serviceUUIDs.map(\.uuidString))
    }
}

/// Clues for recognising a serial-over-BLE box like the PowerBox.
enum PowerBoxHints {
    /// HM-10 style (FFE0), Nordic UART, Microchip transparent UART.
    static let uartServices: Set<String> = [
        "FFE0",
        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E",
        "49535343-FE7D-4AE5-8FA9-9FAFD205E455"
    ]

    /// Characteristics to write commands to, best first.
    static let preferredWrite: [String] = [
        "FFE1",
        "6E400002-B5A3-F393-E0A9-E50E24DCCA9E",
        "49535343-8841-43F4-A8D4-ECBE34729BB3"
    ]

    static let nameHints = ["power", "twizy", "pbox", "pb", "hmsoft", "bt05", "jdy", "hc-", "mlt", "renault"]

    static func isLikely(name: String, services: [String]) -> Bool {
        let lower = name.lowercased()
        if nameHints.contains(where: { lower.contains($0) }) {
            return true
        }
        return services.contains { uartServices.contains($0.uppercased()) }
    }
}

enum Direction: String {
    case incoming = "IN "
    case outgoing = "OUT"
    case info = "---"
}

struct LogEntry: Identifiable {
    let id = UUID()
    let time: Date
    let direction: Direction
    let characteristic: String
    let data: Data
    let note: String?

    var hex: String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    /// Text with control characters made visible (\r, \n, ·).
    var text: String {
        if let note { return note }
        return LogEntry.printable(data)
    }

    static func printable(_ data: Data) -> String {
        var out = ""
        for byte in data {
            switch byte {
            case 0x0D: out += "\\r"
            case 0x0A: out += "\\n"
            case 0x09: out += "\\t"
            case 0x20...0x7E: out.append(Character(UnicodeScalar(byte)))
            default: out += "·"
            }
        }
        return out
    }
}

struct CharacteristicInfo: Identifiable {
    var id: String { uuid }
    let uuid: String
    let serviceUUID: String
    let properties: CBCharacteristicProperties
    var isNotifying: Bool
    var lastValue: Data?

    var propertyText: String {
        var parts: [String] = []
        if properties.contains(.read) { parts.append("read") }
        if properties.contains(.write) { parts.append("write") }
        if properties.contains(.writeWithoutResponse) { parts.append("write-no-resp") }
        if properties.contains(.notify) { parts.append("notify") }
        if properties.contains(.indicate) { parts.append("indicate") }
        return parts.joined(separator: ", ")
    }

    var canWrite: Bool {
        properties.contains(.write) || properties.contains(.writeWithoutResponse)
    }
}

enum LineEnding: String, CaseIterable, Identifiable, Codable {
    case none = "geen"
    case cr = "\\r"
    case lf = "\\n"
    case crlf = "\\r\\n"

    var id: String { rawValue }

    var bytes: String {
        switch self {
        case .none: return ""
        case .cr: return "\r"
        case .lf: return "\n"
        case .crlf: return "\r\n"
        }
    }
}

struct QuickCommand: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var payload: String
    var isHex: Bool = false
    var ending: LineEnding = .crlf
}

/// Parses "A0 01 ff", "a001ff" or "0xA0,0x01" into bytes.
enum HexParser {
    static func data(from text: String) -> Data? {
        let cleaned = text
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: "0X", with: "")
            .filter { $0.isHexDigit }
        guard !cleaned.isEmpty, cleaned.count % 2 == 0 else { return nil }
        var data = Data()
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }
}

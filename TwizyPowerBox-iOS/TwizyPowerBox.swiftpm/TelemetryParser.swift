import Foundation

struct TelemetryField: Equatable {
    let key: String
    let value: Double
    let unit: String?
}

/// Extracts numeric values from one message, whatever the format:
///   {"v":57.3,"soc":81}         -> v=57.3, soc=81
///   V=57.3;SOC:81%;SPD 42       -> V=57.3, SOC=81 (%), SPD=42
///   57.3,12.5,81                -> #1=57.3, #2=12.5, #3=81
/// Text that holds no numbers returns an empty array.
enum TelemetryParser {

    static func parse(_ message: String) -> [TelemetryField] {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") {
            return parseJSON(trimmed)
        }
        let pairs = parseKeyValues(trimmed)
        if !pairs.isEmpty {
            return pairs
        }
        return parseBareNumbers(trimmed)
    }

    // MARK: JSON

    static func parseJSON(_ text: String) -> [TelemetryField] {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else {
            return []
        }
        var fields: [TelemetryField] = []
        for (key, raw) in dict {
            if let number = raw as? NSNumber {
                // JSON true/false also arrive as NSNumber (1/0).
                fields.append(TelemetryField(key: key, value: number.doubleValue, unit: nil))
            } else if let string = raw as? String, let parsed = leadingNumber(string) {
                fields.append(TelemetryField(key: key, value: parsed.0, unit: parsed.1))
            }
        }
        // Keep the order in which the keys appear in the message.
        return fields.sorted { a, b in
            position(of: a.key, in: text) < position(of: b.key, in: text)
        }
    }

    private static func position(of key: String, in text: String) -> Int {
        guard let range = text.range(of: "\"\(key)\"") else { return Int.max }
        return text.distance(from: text.startIndex, to: range.lowerBound)
    }

    // MARK: key=value / key:value / key value

    static func parseKeyValues(_ text: String) -> [TelemetryField] {
        let separators = CharacterSet(charactersIn: ",;|\t")
        var fields: [TelemetryField] = []
        for token in text.components(separatedBy: separators) {
            let part = token.trimmingCharacters(in: .whitespaces)
            guard !part.isEmpty else { continue }

            var key: String?
            var rest: String?
            if let eq = part.firstIndex(where: { $0 == "=" || $0 == ":" }) {
                key = String(part[..<eq]).trimmingCharacters(in: .whitespaces)
                rest = String(part[part.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            } else if let space = part.firstIndex(of: " ") {
                // "SPD 42" style, only when the first word has no digits.
                let word = String(part[..<space])
                if word.rangeOfCharacter(from: .decimalDigits) == nil {
                    key = word
                    rest = String(part[part.index(after: space)...]).trimmingCharacters(in: .whitespaces)
                }
            }
            guard let k = key, !k.isEmpty, let r = rest, let parsed = leadingNumber(r) else {
                continue
            }
            fields.append(TelemetryField(key: k, value: parsed.0, unit: parsed.1))
        }
        return fields
    }

    // MARK: bare CSV numbers

    static func parseBareNumbers(_ text: String) -> [TelemetryField] {
        let separators = CharacterSet(charactersIn: ",;| \t")
        let tokens = text.components(separatedBy: separators).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }
        var fields: [TelemetryField] = []
        for (index, token) in tokens.enumerated() {
            guard let value = Double(token) else { return [] } // not purely numeric
            fields.append(TelemetryField(key: "#\(index + 1)", value: value, unit: nil))
        }
        return fields
    }

    // MARK: helpers

    /// "57.3V" -> (57.3, "V"), "-12" -> (-12, nil), "1.5e-3" -> (0.0015, nil)
    static func leadingNumber(_ text: String) -> (Double, String?)? {
        let chars = Array(text)
        var end = 0
        var seenDigit = false
        var seenExp = false
        while end < chars.count {
            let c = chars[end]
            if c.isASCII && c.isNumber {
                seenDigit = true
            } else if c == "." {
                // fine
            } else if (c == "-" || c == "+") && (end == 0 || chars[end - 1] == "e" || chars[end - 1] == "E") {
                // sign at start or right after the exponent marker
            } else if (c == "e" || c == "E") && seenDigit && !seenExp
                        && end + 1 < chars.count
                        && (chars[end + 1].isNumber || chars[end + 1] == "-" || chars[end + 1] == "+") {
                seenExp = true
            } else {
                break
            }
            end += 1
        }
        guard seenDigit, let value = Double(String(chars[0..<end])) else { return nil }
        let unit = String(chars[end...]).trimmingCharacters(in: .whitespaces)
        return (value, unit.isEmpty ? nil : unit)
    }
}

/// Friendly names for keys we can guess. Unknown keys are shown as-is.
enum FieldCatalog {
    struct Info {
        let label: String
        let unit: String?
    }

    static func info(for key: String) -> Info {
        switch key.lowercased() {
        case "v", "volt", "voltage", "u", "ubat":
            return Info(label: "Spanning", unit: "V")
        case "i", "amp", "current", "a", "ibat":
            return Info(label: "Stroom", unit: "A")
        case "p", "pwr", "power", "w":
            return Info(label: "Vermogen", unit: "W")
        case "soc", "bat", "battery":
            return Info(label: "Accu", unit: "%")
        case "spd", "speed", "kmh", "vel":
            return Info(label: "Snelheid", unit: "km/h")
        case "tmp", "temp", "mtemp", "motortemp":
            return Info(label: "Motortemp", unit: "°C")
        case "ctemp", "ctrltemp":
            return Info(label: "Controller", unit: "°C")
        case "mode", "m", "level", "lvl":
            return Info(label: "Stand", unit: nil)
        case "rpm":
            return Info(label: "Toerental", unit: "rpm")
        default:
            return Info(label: key, unit: nil)
        }
    }

    /// Finds a value by any of its likely key names.
    static func value(_ fields: [String: TelemetryField], _ keys: [String]) -> Double? {
        for key in keys {
            if let hit = fields.first(where: { $0.key.lowercased() == key }) {
                return hit.value.value
            }
        }
        return nil
    }
}

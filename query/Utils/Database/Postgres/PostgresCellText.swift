import Foundation
import PostgresNIO

/// Renders a result cell as text for the SQL console. PostgresNIO asks for binary results, so
/// unlike catalog queries (which cast every column to text) raw SQL needs per-type decoding.
nonisolated enum PostgresCellText {
    static func text(_ cell: PostgresCell) -> String? {
        guard var bytes = cell.bytes else { return nil }
        if cell.format == .text { return String(buffer: bytes) }
        switch cell.dataType {
        case .bool:
            return (try? cell.decode(Bool.self)).map { $0 ? "true" : "false" }
        case .int2, .int4, .int8, .oid:
            return (try? cell.decode(Int.self)).map(String.init)
        case .float4, .float8:
            return (try? cell.decode(Double.self)).map { $0.description }
        case .numeric:
            return (try? cell.decode(Decimal.self)).map { $0.description }
        case .uuid:
            return (try? cell.decode(UUID.self)).map { $0.uuidString.lowercased() }
        case .date:
            return (try? cell.decode(Date.self)).map { $0.formatted(dateStyle) }
        case .timestamp:
            return (try? cell.decode(Date.self)).map { $0.formatted(timestampStyle) }
        case .timestamptz:
            return (try? cell.decode(Date.self)).map { $0.formatted(timestampStyle) + "+00" }
        case .jsonb:
            // Binary jsonb is a version byte followed by the JSON text.
            _ = bytes.readInteger(as: UInt8.self)
            return bytes.readString(length: bytes.readableBytes)
        case .bytea:
            return hex(bytes)
        default:
            // text, varchar, name, char, json, enums… are sent as their UTF-8 text.
            if let text = try? cell.decode(String.self) { return text }
            let raw = String(buffer: bytes)
            return raw.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) ? hex(bytes) : raw
        }
    }

    private static func hex(_ bytes: ByteBuffer) -> String {
        "\\x" + bytes.readableBytesView.map { String(format: "%02x", $0) }.joined()
    }

    private static let utc = TimeZone(identifier: "UTC") ?? .gmt
    private static let dateStyle = Date.ISO8601FormatStyle(timeZone: utc).year().month().day()
    private static let timestampStyle = Date.VerbatimFormatStyle(
        format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)",
        timeZone: utc, calendar: Calendar(identifier: .gregorian)
    )
}

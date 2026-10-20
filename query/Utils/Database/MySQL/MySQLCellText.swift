import Foundation
import MySQLNIO

/// Renders a MySQL / MariaDB value as text. Prepared (binary) results carry dates, times and
/// floating-point numbers as raw bytes that `MySQLData.string` doesn't convert.
nonisolated enum MySQLCellText {
    static func text(_ data: MySQLData) -> String? {
        guard let buffer = data.buffer else { return nil }
        if let string = data.string { return string }
        switch data.type {
        case .date, .datetime, .timestamp, .time:
            if let time = data.time { return format(time, as: data.type) }
        case .float, .double:
            if let double = data.double { return double.description }
        default:
            break
        }
        // DECIMAL and other length-encoded values are already text.
        return String(buffer: buffer)
    }

    private static func format(_ time: MySQLTime, as type: MySQLProtocol.DataType) -> String {
        let date = String(format: "%04d-%02d-%02d", time.year ?? 0, time.month ?? 0, time.day ?? 0)
        var clock = String(format: "%02d:%02d:%02d", time.hour ?? 0, time.minute ?? 0, time.second ?? 0)
        if let microsecond = time.microsecond, microsecond > 0 { clock += String(format: ".%06d", microsecond) }
        switch type {
        case .date: return date
        case .time: return clock
        default: return "\(date) \(clock)"
        }
    }
}

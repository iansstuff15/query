import Foundation

/// ClickHouse over HTTP with server-side typed query parameters (`{p1:Int32}`).
nonisolated struct ClickHouseDialect: SQLDialect {
    var reusesParameters: Bool { true }
    /// ClickHouse edits rows with `ALTER TABLE … UPDATE`, asynchronously; not offered.
    var supportsRowUpdates: Bool { false }

    func quote(_ identifier: String) -> String {
        "`" + identifier.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`") + "`"
    }

    func parameter(_ index: Int, columnType: String?) -> String {
        "{p\(index):\(columnType ?? "String")}"
    }

    func text(_ expression: String) -> String { "toString(\(expression))" }

    func like(_ expression: String, _ pattern: String, negated: Bool) -> String {
        "\(expression) \(negated ? "NOT ILIKE" : "ILIKE") \(pattern)"
    }
}

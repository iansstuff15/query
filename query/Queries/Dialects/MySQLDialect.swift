import Foundation

/// MySQL and MariaDB. Backslash is LIKE's default escape; comparisons coerce types.
nonisolated struct MySQLDialect: SQLDialect {
    var reusesParameters: Bool { false }

    func quote(_ identifier: String) -> String {
        "`" + identifier.replacingOccurrences(of: "`", with: "``") + "`"
    }

    func parameter(_ index: Int, columnType: String?) -> String { "?" }

    func text(_ expression: String) -> String { "CAST(\(expression) AS CHAR)" }

    func like(_ expression: String, _ pattern: String, negated: Bool) -> String {
        "LOWER(\(expression)) \(negated ? "NOT LIKE" : "LIKE") LOWER(\(pattern))"
    }
}

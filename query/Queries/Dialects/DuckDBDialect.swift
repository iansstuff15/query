import Foundation

/// DuckDB: PostgreSQL-like, but LIKE has no default escape character.
nonisolated struct DuckDBDialect: SQLDialect {
    var reusesParameters: Bool { true }

    func quote(_ identifier: String) -> String { identifier.quotedIdentifier }

    func parameter(_ index: Int, columnType: String?) -> String {
        columnType.map { "CAST($\(index) AS \($0))" } ?? "$\(index)"
    }

    func text(_ expression: String) -> String { "CAST(\(expression) AS VARCHAR)" }

    func like(_ expression: String, _ pattern: String, negated: Bool) -> String {
        "\(expression) \(negated ? "NOT ILIKE" : "ILIKE") \(pattern) ESCAPE '\\'"
    }
}

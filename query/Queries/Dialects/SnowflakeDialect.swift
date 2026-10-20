import Foundation

/// Snowflake SQL API: positional `?` bindings, `ILIKE` with an explicit escape.
nonisolated struct SnowflakeDialect: SQLDialect {
    var reusesParameters: Bool { false }

    func quote(_ identifier: String) -> String { identifier.quotedIdentifier }

    func parameter(_ index: Int, columnType: String?) -> String {
        columnType.map { "CAST(? AS \($0))" } ?? "?"
    }

    func text(_ expression: String) -> String { "TO_VARCHAR(\(expression))" }

    func like(_ expression: String, _ pattern: String, negated: Bool) -> String {
        "\(expression) \(negated ? "NOT ILIKE" : "ILIKE") \(pattern) ESCAPE '\\\\'"
    }
}

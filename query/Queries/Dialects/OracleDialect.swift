import Foundation

/// Oracle Database 12c+. `FETCH FIRST n ROWS ONLY`; positional `:N` binds.
nonisolated struct OracleDialect: SQLDialect {
    var reusesParameters: Bool { false }

    func quote(_ identifier: String) -> String { identifier.quotedIdentifier }

    func parameter(_ index: Int, columnType: String?) -> String { ":\(index)" }

    func text(_ expression: String) -> String { "TO_CHAR(\(expression))" }

    /// Oracle treats `''` as `NULL`, so coalescing to empty would be a no-op.
    func coalesceEmpty(_ expression: String) -> String { expression }

    func like(_ expression: String, _ pattern: String, negated: Bool) -> String {
        "UPPER(\(expression)) \(negated ? "NOT LIKE" : "LIKE") UPPER(\(pattern)) ESCAPE '\\'"
    }

    func select(_ columns: String, from table: String, where condition: String?, limit: Int) -> String {
        let filter = condition.map { " WHERE \($0)" } ?? ""
        return "SELECT \(columns) FROM \(table)\(filter) FETCH FIRST \(limit) ROWS ONLY"
    }
}

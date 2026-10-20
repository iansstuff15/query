import Foundation

/// The SQL differences `RowFilterQuery` needs to target an engine.
nonisolated protocol SQLDialect: Sendable {
    func quote(_ identifier: String) -> String
    func table(_ object: DatabaseObject) -> String
    /// Marker for the 1-based parameter `index`, cast to `columnType` when the engine needs it.
    func parameter(_ index: Int, columnType: String?) -> String
    /// Whether a numbered marker can be repeated (`$1`, `@p1`, `?1`) rather than positional `?`.
    var reusesParameters: Bool { get }
    /// Expression rendered as text.
    func text(_ expression: String) -> String
    func coalesceEmpty(_ expression: String) -> String
    /// Case-insensitive `LIKE` with `\` as the escape character.
    func like(_ expression: String, _ pattern: String, negated: Bool) -> String
    func select(_ columns: String, from table: String, where condition: String?, limit: Int) -> String
    /// Whether rows can be edited with a plain `UPDATE … SET … WHERE …`.
    var supportsRowUpdates: Bool { get }
}

nonisolated extension SQLDialect {
    func table(_ object: DatabaseObject) -> String {
        "\(quote(object.schema)).\(quote(object.name))"
    }

    var supportsRowUpdates: Bool { true }

    func coalesceEmpty(_ expression: String) -> String {
        "COALESCE(\(expression), '')"
    }

    func select(_ columns: String, from table: String, where condition: String?, limit: Int) -> String {
        let filter = condition.map { " WHERE \($0)" } ?? ""
        return "SELECT \(columns) FROM \(table)\(filter) LIMIT \(limit)"
    }
}

import Foundation

/// SQLite, libSQL/Turso and Cloudflare D1. `?NNN` markers can be repeated.
nonisolated struct SQLiteDialect: SQLDialect {
    var reusesParameters: Bool { true }

    func quote(_ identifier: String) -> String { identifier.quotedIdentifier }

    /// SQLite has one schema per attached database; `main` is implied.
    func table(_ object: DatabaseObject) -> String {
        object.schema == "main" ? quote(object.name) : "\(quote(object.schema)).\(quote(object.name))"
    }

    func parameter(_ index: Int, columnType: String?) -> String { "?\(index)" }

    func text(_ expression: String) -> String { "CAST(\(expression) AS TEXT)" }

    func like(_ expression: String, _ pattern: String, negated: Bool) -> String {
        "LOWER(\(expression)) \(negated ? "NOT LIKE" : "LIKE") LOWER(\(pattern)) ESCAPE '\\'"
    }
}

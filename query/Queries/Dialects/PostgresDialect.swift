import Foundation

/// PostgreSQL and wire-compatible engines (CockroachDB, Greenplum, Redshift, Vertica).
nonisolated struct PostgresDialect: SQLDialect {
    /// Text type for casts; Redshift's `text` is `varchar(256)`, so it uses a wider type.
    var textType = "text"
    /// Vertica speaks the protocol but only accepts `?` markers.
    var usesQuestionMarks = false

    static let postgres = PostgresDialect()
    static let redshift = PostgresDialect(textType: "varchar(65535)")
    static let vertica = PostgresDialect(textType: "varchar(65000)", usesQuestionMarks: true)

    var reusesParameters: Bool { !usesQuestionMarks }

    func quote(_ identifier: String) -> String { identifier.quotedIdentifier }

    func parameter(_ index: Int, columnType: String?) -> String {
        let marker = usesQuestionMarks ? "?" : "$\(index)"
        return columnType.map { "CAST(\(marker) AS \($0))" } ?? marker
    }

    func text(_ expression: String) -> String { "CAST(\(expression) AS \(textType))" }

    func like(_ expression: String, _ pattern: String, negated: Bool) -> String {
        "\(expression) \(negated ? "NOT ILIKE" : "ILIKE") \(pattern)"
    }
}

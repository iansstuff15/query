import Foundation

/// Microsoft SQL Server (T-SQL). `TOP (n)` instead of `LIMIT`; `@pN` named parameters.
nonisolated struct SQLServerDialect: SQLDialect {
    var reusesParameters: Bool { true }

    func quote(_ identifier: String) -> String {
        "[" + identifier.replacingOccurrences(of: "]", with: "]]") + "]"
    }

    func parameter(_ index: Int, columnType: String?) -> String { "@p\(index)" }

    func text(_ expression: String) -> String { "CAST(\(expression) AS NVARCHAR(4000))" }

    func like(_ expression: String, _ pattern: String, negated: Bool) -> String {
        "LOWER(\(expression)) \(negated ? "NOT LIKE" : "LIKE") LOWER(\(pattern)) ESCAPE '\\'"
    }

    func select(_ columns: String, from table: String, where condition: String?, limit: Int) -> String {
        let filter = condition.map { " WHERE \($0)" } ?? ""
        return "SELECT TOP (\(limit)) \(columns) FROM \(table)\(filter)"
    }
}

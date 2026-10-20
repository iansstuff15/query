import Foundation

/// GoogleSQL. Backtick-quoted paths and named `@pN` parameters bound as STRING.
nonisolated struct BigQueryDialect: SQLDialect {
    var reusesParameters: Bool { true }

    func quote(_ identifier: String) -> String {
        "`" + identifier.replacingOccurrences(of: "`", with: "\\`") + "`"
    }

    func parameter(_ index: Int, columnType: String?) -> String {
        columnType.map { "CAST(@p\(index) AS \($0))" } ?? "@p\(index)"
    }

    func text(_ expression: String) -> String { "CAST(\(expression) AS STRING)" }

    func like(_ expression: String, _ pattern: String, negated: Bool) -> String {
        "LOWER(\(expression)) \(negated ? "NOT LIKE" : "LIKE") LOWER(\(pattern))"
    }
}

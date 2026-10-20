import Foundation

/// SQL text with positional (`$1`, `$2`, …) text bindings. Values are never interpolated.
nonisolated struct SQLStatement: Hashable, Sendable {
    let sql: String
    let bindings: [String]

    init(sql: String, bindings: [String] = []) {
        self.sql = sql
        self.bindings = bindings
    }
}

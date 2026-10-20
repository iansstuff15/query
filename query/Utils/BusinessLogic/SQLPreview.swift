import Foundation

/// Formats a statement and its bindings for the filter bar, e.g. `… ILIKE $1  — 1 = '%ada%'`.
nonisolated enum SQLPreview {
    static func text(_ statement: SQLStatement) -> String {
        guard !statement.bindings.isEmpty else { return statement.sql }
        let bindings = statement.bindings.enumerated()
            .map { "\($0.offset + 1) = '\($0.element)'" }
            .joined(separator: ", ")
        return "\(statement.sql)  — \(bindings)"
    }
}

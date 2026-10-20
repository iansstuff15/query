import Foundation

/// A result-set row rendered as text; `nil` is SQL `NULL`.
nonisolated struct ResultRow: Identifiable, Hashable, Sendable {
    let id: Int
    let values: [String?]

    subscript(column: ResultColumn) -> String? {
        values.indices.contains(column.id) ? values[column.id] : nil
    }
}

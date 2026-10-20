import Foundation

/// Edits to one row of a table: its values before and after, aligned with `columns`, and the
/// columns that identify it.
nonisolated struct RowChange: Equatable, Sendable {
    let object: DatabaseObject
    let columns: [ColumnInfo]
    /// The row as loaded (`nil` is SQL `NULL`).
    let original: [String?]
    /// The row as edited.
    let values: [String?]
    /// Primary-key columns; empty when the table has none, so every column's original value
    /// identifies the row instead.
    let keyColumns: [String]

    /// Indexes of the columns whose value changed.
    var changedIndexes: [Int] {
        columns.indices.filter { original.indices.contains($0) && values.indices.contains($0) && original[$0] != values[$0] }
    }
}

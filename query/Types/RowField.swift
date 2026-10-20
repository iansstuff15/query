import Foundation

/// One column of the row being edited in the Row tab.
nonisolated struct RowField: Identifiable, Equatable, Sendable {
    /// The column's position in the row.
    let id: Int
    let column: ColumnInfo
    /// The value as loaded (`nil` is SQL `NULL`).
    let original: String?
    /// The text in the field; ignored while `isNull`.
    var text: String
    var isNull: Bool

    init(index: Int, column: ColumnInfo, original: String?) {
        id = index
        self.column = column
        self.original = original
        text = original ?? ""
        isNull = original == nil
    }

    /// The value to save.
    var value: String? { isNull ? nil : text }

    var isChanged: Bool { value != original }
}

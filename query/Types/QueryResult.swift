import Foundation

nonisolated struct QueryResult: Hashable, Sendable {
    let columns: [ResultColumn]
    let rows: [ResultRow]

    init(columns: [ResultColumn], rows: [ResultRow]) {
        self.columns = columns
        self.rows = rows
    }

    /// Builds a result from column metadata and raw text rows.
    init(columns: [ColumnInfo], values: [[String?]]) {
        self.columns = columns.enumerated().map { ResultColumn(id: $0.offset, name: $0.element.name) }
        self.rows = values.enumerated().map { ResultRow(id: $0.offset, values: $0.element) }
    }

    /// Builds a result from column names and raw text rows (SQL console output).
    init(columnNames: [String], values: [[String?]]) {
        self.columns = columnNames.enumerated().map { ResultColumn(id: $0.offset, name: $0.element) }
        self.rows = values.enumerated().map { ResultRow(id: $0.offset, values: $0.element) }
    }

    var isEmpty: Bool { rows.isEmpty }
}

import Foundation

/// `UPDATE table SET changed = … WHERE key = …` for one edited row. Values only travel as
/// bindings; new values are cast to their column's type (`CAST($1 AS integer)`), and the row is
/// matched by comparing each key column as text against the text the grid loaded, so any type
/// matches exactly. `NULL`s become `= NULL` / `IS NULL`.
nonisolated struct RowUpdateQuery: Sendable {
    let change: RowChange
    let dialect: any SQLDialect

    /// `nil` when nothing changed.
    func statement() -> SQLStatement? {
        let changed = change.changedIndexes
        guard !changed.isEmpty else { return nil }
        var bindings: [String] = []
        func bind(_ value: String, columnType: String?) -> String {
            bindings.append(value)
            return dialect.parameter(bindings.count, columnType: columnType)
        }

        let assignments = changed.map { index -> String in
            let column = change.columns[index]
            let quoted = dialect.quote(column.name)
            guard let value = change.values[index] else { return "\(quoted) = NULL" }
            let type = column.dataType.isSafeSQLTypeName ? column.dataType : nil
            return "\(quoted) = \(bind(value, columnType: type))"
        }

        let keyIndexes = keyColumnIndexes
        let conditions = keyIndexes.map { index -> String in
            let quoted = dialect.quote(change.columns[index].name)
            guard let original = change.original[index] else { return "\(quoted) IS NULL" }
            return "\(dialect.text(quoted)) = \(bind(original, columnType: nil))"
        }

        let sql = "UPDATE \(dialect.table(change.object)) SET \(assignments.joined(separator: ", ")) WHERE \(conditions.joined(separator: " AND "))"
        return SQLStatement(sql: sql, bindings: bindings)
    }

    /// The primary key's columns when known, otherwise every column.
    private var keyColumnIndexes: [Int] {
        let keys = change.keyColumns.compactMap { name in change.columns.firstIndex { $0.name == name } }
        return keys.isEmpty || keys.count != change.keyColumns.count ? Array(change.columns.indices) : keys
    }
}

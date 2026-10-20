import Foundation

/// A SQL driver. Conformers supply a transport (`execute`) and catalog SQL; listing,
/// columns and filtered rows come from the extension.
///
/// Catalog statements must return `[schema, name, kind]` rows (kind as a `pg_class.relkind`
/// letter) and `[name, type]` column rows, all as text.
nonisolated protocol SQLExecuting: SQLConsoleRunning, RowUpdating {
    var dialect: any SQLDialect { get }
    func execute(_ statement: SQLStatement) async throws -> [[String?]]
    func objectsStatement() -> SQLStatement
    func columnsStatement(of object: DatabaseObject) -> SQLStatement
    /// Catalog SQL returning the primary-key column names (`[name]` rows, in key order), or
    /// `nil` when the engine's catalog isn't supported.
    func primaryKeyStatement(of object: DatabaseObject) -> SQLStatement?
    /// Catalog SQL returning the names of the columns the current user can update (`[name]`
    /// rows), or `nil` when the engine's catalog isn't supported.
    func editableColumnsStatement(of object: DatabaseObject) -> SQLStatement?
}

nonisolated extension SQLExecuting {
    func listObjects() async throws -> [DatabaseObject] {
        try await execute(objectsStatement()).compactMap { row in
            guard row.count >= 3, let schema = row[0], let name = row[1],
                  let kind = row[2].flatMap(DatabaseObjectKind.init(relkind:)) else { return nil }
            return DatabaseObject(schema: schema, name: name, kind: kind)
        }
    }

    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] {
        try await execute(columnsStatement(of: object)).compactMap { row in
            guard row.count >= 2, let name = row[0] else { return nil }
            return ColumnInfo(name: name, dataType: row[1] ?? "")
        }
    }

    func queryPreview(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) -> String? {
        SQLPreview.text(RowFilterQuery(object: object, columns: columns, rules: rules, limit: limit, dialect: dialect).statement())
    }

    func rows(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) async throws -> QueryResult {
        let statement = RowFilterQuery(object: object, columns: columns, rules: rules, limit: limit, dialect: dialect).statement()
        return QueryResult(columns: columns, values: try await execute(statement))
    }

    func primaryKeyStatement(of object: DatabaseObject) -> SQLStatement? { nil }

    func editableColumnsStatement(of object: DatabaseObject) -> SQLStatement? { nil }

    func editableColumns(of object: DatabaseObject) async throws -> Set<String>? {
        guard canUpdateRows else { return [] }
        guard let statement = editableColumnsStatement(of: object) else { return nil }
        return Set(try await execute(statement).compactMap { $0.first ?? nil })
    }

    var canUpdateRows: Bool { dialect.supportsRowUpdates }

    func primaryKey(of object: DatabaseObject) async throws -> [String] {
        guard let statement = primaryKeyStatement(of: object) else { return [] }
        return try await execute(statement).compactMap { $0.first ?? nil }
    }

    func update(_ change: RowChange) async throws {
        guard canUpdateRows else { throw DatabaseError.unsupported }
        guard let statement = RowUpdateQuery(change: change, dialect: dialect).statement() else { return }
        _ = try await execute(statement)
    }

    /// Drivers whose transport doesn't report column names label columns by position;
    /// drivers that know the names override this.
    func runSQL(_ sql: String) async throws -> QueryResult {
        let values = try await execute(SQLStatement(sql: sql))
        let width = values.map(\.count).max() ?? 0
        return QueryResult(columnNames: (0..<width).map { "#\($0 + 1)" }, values: values)
    }
}

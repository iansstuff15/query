import Foundation

/// A SQL driver. Conformers supply a transport (`execute`) and catalog SQL; listing,
/// columns and filtered rows come from the extension.
///
/// Catalog statements must return `[schema, name, kind]` rows (kind as a `pg_class.relkind`
/// letter) and `[name, type]` column rows, all as text.
nonisolated protocol SQLExecuting: SQLConsoleRunning, RowUpdating, UserManaging {
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
    /// The engine's user and permission SQL, or `nil` when it isn't supported.
    func userManagementSQL() -> (any UserManagementSQL)?
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

    // MARK: - Users and permissions

    func userManagementSQL() -> (any UserManagementSQL)? { nil }

    var userManagement: UserManagementCapabilities? { userManagementSQL()?.capabilities }

    func users() async throws -> [DatabaseUser] {
        let sql = try requireUserManagementSQL()
        return try await execute(sql.listUsers).compactMap(sql.user(from:))
    }

    func createUser(_ draft: UserDraft) async throws {
        try await run(try requireUserManagementSQL().create(draft))
    }

    func updateUser(_ user: DatabaseUser, to draft: UserDraft) async throws {
        try await run(try requireUserManagementSQL().update(user, to: draft))
    }

    func dropUser(_ user: DatabaseUser) async throws {
        try await run(try requireUserManagementSQL().drop(user))
    }

    func grants(of user: DatabaseUser) async throws -> [GrantTarget: Set<TablePrivilege>] {
        let sql = try requireUserManagementSQL()
        return sql.grants(from: try await execute(sql.grantsStatement(of: user)))
    }

    func changeGrants(
        of user: DatabaseUser, granting added: [GrantTarget: Set<TablePrivilege>], revoking removed: [GrantTarget: Set<TablePrivilege>]
    ) async throws {
        let sql = try requireUserManagementSQL()
        // Revokes first, then grants, each in a stable order.
        for (target, privileges) in removed.sorted(by: { $0.key < $1.key }) {
            try await run(sql.revoke(privileges, on: target, from: user))
        }
        for (target, privileges) in added.sorted(by: { $0.key < $1.key }) {
            try await run(sql.grant(privileges, on: target, to: user))
        }
    }

    private func requireUserManagementSQL() throws -> any UserManagementSQL {
        guard let sql = userManagementSQL() else { throw DatabaseError.unsupported }
        return sql
    }

    private func run(_ statements: [SQLStatement]) async throws {
        for statement in statements { _ = try await execute(statement) }
    }

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

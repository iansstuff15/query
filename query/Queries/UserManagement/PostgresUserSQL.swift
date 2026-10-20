import Foundation

/// Users and permissions for PostgreSQL: roles with LOGIN / SUPERUSER / CREATEDB / CREATEROLE,
/// and table privileges read from each table's ACL (so an administrator sees every role's).
nonisolated struct PostgresUserSQL: UserManagementSQL {
    var capabilities: UserManagementCapabilities { .postgres }

    var listUsers: SQLStatement {
        SQLStatement(sql: """
            SELECT CAST(rolname AS text), CAST(rolsuper AS text), CAST(rolcanlogin AS text),
                   CAST(rolcreatedb AS text), CAST(rolcreaterole AS text)
            FROM pg_catalog.pg_roles WHERE rolname !~ '^pg_' ORDER BY rolname
            """)
    }

    func user(from row: [String?]) -> DatabaseUser? {
        guard row.count >= 5, let name = row[0] else { return nil }
        let flags: [(Int, UserOption)] = [(1, .superuser), (2, .login), (3, .createDatabases), (4, .createRoles)]
        return DatabaseUser(name: name, host: nil, options: Set(flags.filter { row[$0.0] == "true" }.map(\.1)))
    }

    func create(_ draft: UserDraft) throws -> [SQLStatement] {
        try validate(draft)
        return [SQLStatement(sql: "CREATE ROLE \(draft.trimmedName.quotedIdentifier) WITH \(attributes(draft))")]
    }

    func update(_ user: DatabaseUser, to draft: UserDraft) throws -> [SQLStatement] {
        try validate(draft)
        var statements: [SQLStatement] = []
        if draft.trimmedName != user.name {
            statements.append(SQLStatement(sql: "ALTER ROLE \(user.name.quotedIdentifier) RENAME TO \(draft.trimmedName.quotedIdentifier)"))
        }
        statements.append(SQLStatement(sql: "ALTER ROLE \(draft.trimmedName.quotedIdentifier) WITH \(attributes(draft))"))
        return statements
    }

    /// A role with privileges can't be dropped. Hand anything it owns to the administrator doing
    /// the drop (so nothing is deleted), then revoke its privileges, then drop it.
    func drop(_ user: DatabaseUser) -> [SQLStatement] {
        let role = user.name.quotedIdentifier
        return [
            SQLStatement(sql: "REASSIGN OWNED BY \(role) TO CURRENT_USER"),
            SQLStatement(sql: "DROP OWNED BY \(role)"),
            SQLStatement(sql: "DROP ROLE \(role)"),
        ]
    }

    func grantsStatement(of user: DatabaseUser) -> SQLStatement {
        SQLStatement(
            sql: """
                SELECT CAST(n.nspname AS text), CAST(c.relname AS text), CAST(p.privilege_type AS text)
                FROM pg_catalog.pg_class c
                JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                CROSS JOIN LATERAL aclexplode(c.relacl) p
                JOIN pg_catalog.pg_roles r ON r.oid = p.grantee
                WHERE r.rolname = $1 AND c.relkind IN ('r', 'v', 'm', 'p', 'f')
                """,
            bindings: [user.name]
        )
    }

    func grant(_ privileges: Set<TablePrivilege>, on target: GrantTarget, to user: DatabaseUser) -> [SQLStatement] {
        guard !privileges.isEmpty else { return [] }
        let role = user.name.quotedIdentifier
        // Table privileges are useless without USAGE on the schema.
        return [
            SQLStatement(sql: "GRANT USAGE ON SCHEMA \(target.schema.quotedIdentifier) TO \(role)"),
            SQLStatement(sql: "GRANT \(privilegeList(privileges)) ON \(on(target)) TO \(role)"),
        ]
    }

    func revoke(_ privileges: Set<TablePrivilege>, on target: GrantTarget, from user: DatabaseUser) -> [SQLStatement] {
        guard !privileges.isEmpty else { return [] }
        return [SQLStatement(sql: "REVOKE \(privilegeList(privileges)) ON \(on(target)) FROM \(user.name.quotedIdentifier)")]
    }

    private func on(_ target: GrantTarget) -> String {
        switch target {
        case .schema(let schema): "ALL TABLES IN SCHEMA \(schema.quotedIdentifier)"
        case .table(let schema, let name): "TABLE \(schema.quotedIdentifier).\(name.quotedIdentifier)"
        }
    }

    private func attributes(_ draft: UserDraft) -> String {
        var words = [
            draft.options.contains(.login) ? "LOGIN" : "NOLOGIN",
            draft.options.contains(.superuser) ? "SUPERUSER" : "NOSUPERUSER",
            draft.options.contains(.createDatabases) ? "CREATEDB" : "NOCREATEDB",
            draft.options.contains(.createRoles) ? "CREATEROLE" : "NOCREATEROLE",
        ]
        if !draft.password.isEmpty { words.append("PASSWORD \(draft.password.postgresStringLiteral)") }
        return words.joined(separator: " ")
    }
}

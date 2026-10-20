import Foundation

/// Users and permissions for MySQL and MariaDB: `'user'@'host'` accounts (login is "the account
/// isn't locked"), with grants on `schema.*` and on single tables.
nonisolated struct MySQLUserSQL: UserManagementSQL {
    var capabilities: UserManagementCapabilities { .mySQL }

    var listUsers: SQLStatement {
        SQLStatement(sql: """
            SELECT User, Host, account_locked FROM mysql.user
            WHERE User NOT IN ('', 'mysql.sys', 'mysql.session', 'mysql.infoschema')
            ORDER BY User, Host
            """)
    }

    func user(from row: [String?]) -> DatabaseUser? {
        guard row.count >= 3, let name = row[0], let host = row[1] else { return nil }
        return DatabaseUser(name: name, host: host, options: row[2] == "Y" ? [] : [.login])
    }

    func create(_ draft: UserDraft) throws -> [SQLStatement] {
        try validate(draft)
        let password = draft.password.isEmpty ? "" : " IDENTIFIED BY \(draft.password.mySQLStringLiteral)"
        return [SQLStatement(sql: "CREATE USER \(account(draft.trimmedName, draft.trimmedHost))\(password) \(lock(draft))")]
    }

    func update(_ user: DatabaseUser, to draft: UserDraft) throws -> [SQLStatement] {
        try validate(draft)
        var statements: [SQLStatement] = []
        let current = account(user.name, user.host ?? "%")
        let renamed = account(draft.trimmedName, draft.trimmedHost)
        if renamed != current {
            statements.append(SQLStatement(sql: "RENAME USER \(current) TO \(renamed)"))
        }
        let password = draft.password.isEmpty ? "" : " IDENTIFIED BY \(draft.password.mySQLStringLiteral)"
        statements.append(SQLStatement(sql: "ALTER USER \(renamed)\(password) \(lock(draft))"))
        return statements
    }

    func drop(_ user: DatabaseUser) -> [SQLStatement] {
        [SQLStatement(sql: "DROP USER \(account(user.name, user.host ?? "%"))")]
    }

    func grantsStatement(of user: DatabaseUser) -> SQLStatement {
        let grantee = grantee(user)
        return SQLStatement(
            sql: """
                SELECT TABLE_SCHEMA, NULL, PRIVILEGE_TYPE FROM information_schema.SCHEMA_PRIVILEGES WHERE GRANTEE = ?
                UNION ALL
                SELECT TABLE_SCHEMA, TABLE_NAME, PRIVILEGE_TYPE FROM information_schema.TABLE_PRIVILEGES WHERE GRANTEE = ?
                """,
            bindings: [grantee, grantee]
        )
    }

    func grant(_ privileges: Set<TablePrivilege>, on target: GrantTarget, to user: DatabaseUser) -> [SQLStatement] {
        guard !privileges.isEmpty else { return [] }
        return [SQLStatement(sql: "GRANT \(privilegeList(privileges)) ON \(on(target)) TO \(account(user.name, user.host ?? "%"))")]
    }

    func revoke(_ privileges: Set<TablePrivilege>, on target: GrantTarget, from user: DatabaseUser) -> [SQLStatement] {
        guard !privileges.isEmpty else { return [] }
        return [SQLStatement(sql: "REVOKE \(privilegeList(privileges)) ON \(on(target)) FROM \(account(user.name, user.host ?? "%"))")]
    }

    private func on(_ target: GrantTarget) -> String {
        switch target {
        case .schema(let schema): "\(schema.mySQLIdentifier).*"
        case .table(let schema, let name): "\(schema.mySQLIdentifier).\(name.mySQLIdentifier)"
        }
    }

    private func account(_ name: String, _ host: String) -> String {
        "\(name.mySQLStringLiteral)@\(host.mySQLStringLiteral)"
    }

    /// How information_schema writes the account: `'name'@'host'`.
    private func grantee(_ user: DatabaseUser) -> String {
        "'\(user.name)'@'\(user.host ?? "%")'"
    }

    private func lock(_ draft: UserDraft) -> String {
        draft.options.contains(.login) ? "ACCOUNT UNLOCK" : "ACCOUNT LOCK"
    }
}

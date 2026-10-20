import Testing
@testable import query

@Suite("UserManagementSQL")
struct UserManagementSQLTests {
    private let postgres = PostgresUserSQL()
    private let mySQL = MySQLUserSQL()

    // MARK: PostgreSQL

    @Test func postgresCreatesARoleWithOptionsAndAnEscapedPassword() throws {
        let draft = UserDraft(name: " ana ", password: "it's\\secret", options: [.login, .createDatabases])
        #expect(try postgres.create(draft).map(\.sql) == [
            #"CREATE ROLE "ana" WITH LOGIN NOSUPERUSER CREATEDB NOCREATEROLE PASSWORD 'it''s\secret'"#,
        ])
    }

    @Test func postgresRenamesThenAltersAndKeepsThePasswordWhenEmpty() throws {
        let user = DatabaseUser(name: "ana", host: nil, options: [.login])
        let statements = try postgres.update(user, to: UserDraft(name: "ana_b", options: [.superuser]))
        #expect(statements.map(\.sql) == [
            #"ALTER ROLE "ana" RENAME TO "ana_b""#,
            #"ALTER ROLE "ana_b" WITH NOLOGIN SUPERUSER NOCREATEDB NOCREATEROLE"#,
        ])
    }

    @Test func postgresQuotesIdentifiersThatContainQuotes() throws {
        let user = DatabaseUser(name: #"we"ird"#, host: nil, options: [])
        #expect(postgres.drop(user).map(\.sql) == [
            #"REASSIGN OWNED BY "we""ird" TO CURRENT_USER"#,
            #"DROP OWNED BY "we""ird""#,
            #"DROP ROLE "we""ird""#,
        ])
    }

    @Test func postgresGrantsWithSchemaUsageAndRevokes() {
        let user = DatabaseUser(name: "ana", host: nil, options: [])
        let target = GrantTarget.table(schema: "public", name: "customers")
        #expect(postgres.grant([.update, .select], on: target, to: user).map(\.sql) == [
            #"GRANT USAGE ON SCHEMA "public" TO "ana""#,
            #"GRANT SELECT, UPDATE ON TABLE "public"."customers" TO "ana""#,
        ])
        #expect(postgres.revoke([.delete], on: .schema("sales"), from: user).map(\.sql) == [
            #"REVOKE DELETE ON ALL TABLES IN SCHEMA "sales" FROM "ana""#,
        ])
        #expect(postgres.grant([], on: target, to: user).isEmpty)
    }

    @Test func postgresReadsUsersAndGrants() {
        #expect(postgres.user(from: ["ana", "false", "true", "true", "false"]) == DatabaseUser(name: "ana", host: nil, options: [.login, .createDatabases]))
        #expect(postgres.grantsStatement(of: DatabaseUser(name: "ana", host: nil, options: [])).bindings == ["ana"])
        let grants = postgres.grants(from: [["public", "customers", "SELECT"], ["public", "customers", "UPDATE"], ["public", "orders", "TRUNCATE"]])
        #expect(grants == [.table(schema: "public", name: "customers"): [.select, .update]])
    }

    // MARK: MySQL / MariaDB

    @Test func mySQLCreatesAnAccountWithHostPasswordAndLock() throws {
        let draft = UserDraft(name: "ana", host: "10.0.%", password: #"pa'ss\word"#, options: [])
        #expect(try mySQL.create(draft).map(\.sql) == [#"CREATE USER 'ana'@'10.0.%' IDENTIFIED BY 'pa''ss\\word' ACCOUNT LOCK"#])
        #expect(try mySQL.create(UserDraft(name: "bo", host: " ")).map(\.sql) == ["CREATE USER 'bo'@'%' ACCOUNT UNLOCK"])
    }

    @Test func mySQLRenamesAccountsAndAltersThem() throws {
        let user = DatabaseUser(name: "ana", host: "%", options: [.login])
        #expect(try mySQL.update(user, to: UserDraft(name: "ana", host: "%", options: [.login])).map(\.sql) == ["ALTER USER 'ana'@'%' ACCOUNT UNLOCK"])
        #expect(try mySQL.update(user, to: UserDraft(name: "anna", host: "localhost", password: "x", options: [])).map(\.sql) == [
            "RENAME USER 'ana'@'%' TO 'anna'@'localhost'",
            "ALTER USER 'anna'@'localhost' IDENTIFIED BY 'x' ACCOUNT LOCK",
        ])
    }

    @Test func mySQLGrantsOnSchemasAndTables() {
        let user = DatabaseUser(name: "ana", host: "%", options: [])
        #expect(mySQL.grant([.select], on: .schema("app"), to: user).map(\.sql) == ["GRANT SELECT ON `app`.* TO 'ana'@'%'"])
        #expect(mySQL.revoke([.insert, .delete], on: .table(schema: "app", name: "or`ders"), from: user).map(\.sql) == [
            "REVOKE INSERT, DELETE ON `app`.`or``ders` FROM 'ana'@'%'",
        ])
        #expect(mySQL.grantsStatement(of: user).bindings == ["'ana'@'%'", "'ana'@'%'"])
        let grants = mySQL.grants(from: [["app", nil, "SELECT"], ["app", "orders", "INSERT"]])
        #expect(grants == [.schema("app"): [.select], .table(schema: "app", name: "orders"): [.insert]])
        #expect(mySQL.user(from: ["ana", "%", "Y"]) == DatabaseUser(name: "ana", host: "%", options: []))
    }

    // MARK: Validation

    @Test func invalidFormsAreRejectedBeforeAnySQL() {
        #expect(throws: UserManagementError.emptyName) { try postgres.create(UserDraft(name: "  ")) }
        #expect(throws: UserManagementError.nameTooLong(maximum: 32)) { try mySQL.create(UserDraft(name: String(repeating: "a", count: 33))) }
        #expect(throws: UserManagementError.invalidCharacter) { try postgres.create(UserDraft(name: "a", password: "x\0y")) }
    }
}

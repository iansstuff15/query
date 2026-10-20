import Foundation

/// What an engine's user management offers.
nonisolated struct UserManagementCapabilities: Equatable, Sendable {
    /// Options shown as toggles in the user form.
    let options: [UserOption]
    /// Accounts are `user@host` (MySQL / MariaDB).
    let usesHosts: Bool
    /// Schema-wide grants are stored as such (`schema.*` in MySQL). Otherwise the schema row of
    /// the permissions grid sets every table in the schema at once.
    let storesSchemaGrants: Bool
    /// Longest user name the engine accepts.
    let maxNameLength: Int

    static let postgres = UserManagementCapabilities(
        options: [.login, .superuser, .createDatabases, .createRoles], usesHosts: false, storesSchemaGrants: false, maxNameLength: 63
    )
    static let mySQL = UserManagementCapabilities(options: [.login], usesHosts: true, storesSchemaGrants: true, maxNameLength: 32)
}

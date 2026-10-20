import Foundation

/// A client that can list, create, change and drop database users and set their table
/// permissions (the Users & Permissions window). Every call needs an administrator's login;
/// refusals throw `DatabaseError.statementFailed` with the server's message.
nonisolated protocol UserManaging: DatabaseClient {
    /// `nil` when this connection's engine has no user management.
    var userManagement: UserManagementCapabilities? { get }
    func users() async throws -> [DatabaseUser]
    func createUser(_ draft: UserDraft) async throws
    /// Applies `draft` (name, host, password if not empty, options) to `user`.
    func updateUser(_ user: DatabaseUser, to draft: UserDraft) async throws
    func dropUser(_ user: DatabaseUser) async throws
    /// The user's table and schema privileges.
    func grants(of user: DatabaseUser) async throws -> [GrantTarget: Set<TablePrivilege>]
    /// Grants `added` and revokes `removed`, per target.
    func changeGrants(of user: DatabaseUser, granting added: [GrantTarget: Set<TablePrivilege>], revoking removed: [GrantTarget: Set<TablePrivilege>]) async throws
}

@testable import query

/// `UserManaging` double that keeps users and grants in memory, records changes, and can refuse
/// like a non-administrator.
actor MockUserManager: UserManaging {
    nonisolated let userManagement: UserManagementCapabilities?
    private(set) var storedUsers: [DatabaseUser]
    private(set) var storedGrants: [String: [GrantTarget: Set<TablePrivilege>]]
    private(set) var grantCalls: [(added: [GrantTarget: Set<TablePrivilege>], removed: [GrantTarget: Set<TablePrivilege>])] = []
    var failure: String?
    let objects: [DatabaseObject]

    init(
        capabilities: UserManagementCapabilities? = .postgres, users: [DatabaseUser] = [], grants: [String: [GrantTarget: Set<TablePrivilege>]] = [:],
        objects: [DatabaseObject] = [], failure: String? = nil
    ) {
        userManagement = capabilities
        storedUsers = users
        storedGrants = grants
        self.objects = objects
        self.failure = failure
    }

    func setFailure(_ message: String?) { failure = message }

    func users() async throws -> [DatabaseUser] {
        try check()
        return storedUsers
    }

    func createUser(_ draft: UserDraft) async throws {
        try check()
        if draft.trimmedName.isEmpty { throw UserManagementError.emptyName }
        storedUsers.append(DatabaseUser(name: draft.trimmedName, host: userManagement?.usesHosts == true ? draft.trimmedHost : nil, options: draft.options))
    }

    func updateUser(_ user: DatabaseUser, to draft: UserDraft) async throws {
        try check()
        storedUsers.removeAll { $0.id == user.id }
        storedUsers.append(DatabaseUser(name: draft.trimmedName, host: user.host == nil ? nil : draft.trimmedHost, options: draft.options))
    }

    func dropUser(_ user: DatabaseUser) async throws {
        try check()
        storedUsers.removeAll { $0.id == user.id }
    }

    func grants(of user: DatabaseUser) async throws -> [GrantTarget: Set<TablePrivilege>] {
        try check()
        return storedGrants[user.id] ?? [:]
    }

    func changeGrants(
        of user: DatabaseUser, granting added: [GrantTarget: Set<TablePrivilege>], revoking removed: [GrantTarget: Set<TablePrivilege>]
    ) async throws {
        try check()
        grantCalls.append((added, removed))
        var grants = storedGrants[user.id] ?? [:]
        for (target, privileges) in removed { grants[target]?.subtract(privileges) }
        for (target, privileges) in added { grants[target, default: []].formUnion(privileges) }
        storedGrants[user.id] = grants
    }

    func listObjects() async throws -> [DatabaseObject] { objects }
    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] { [] }
    func rows(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) async throws -> QueryResult {
        QueryResult(columns: columns, values: [])
    }

    private func check() throws {
        if let failure { throw DatabaseError.statementFailed(failure) }
    }
}

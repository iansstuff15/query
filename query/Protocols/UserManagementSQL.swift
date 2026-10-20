import Foundation

/// The SQL an engine uses for users and permissions. Names and passwords can't be bind
/// parameters in these statements, so builders quote identifiers and escape literals themselves,
/// and only `TablePrivilege` names are written as privilege words.
nonisolated protocol UserManagementSQL: Sendable {
    var capabilities: UserManagementCapabilities { get }
    var listUsers: SQLStatement { get }
    func user(from row: [String?]) -> DatabaseUser?
    func create(_ draft: UserDraft) throws -> [SQLStatement]
    func update(_ user: DatabaseUser, to draft: UserDraft) throws -> [SQLStatement]
    func drop(_ user: DatabaseUser) -> [SQLStatement]
    /// Rows of `[schema, table or NULL for the whole schema, privilege]`.
    func grantsStatement(of user: DatabaseUser) -> SQLStatement
    func grant(_ privileges: Set<TablePrivilege>, on target: GrantTarget, to user: DatabaseUser) -> [SQLStatement]
    func revoke(_ privileges: Set<TablePrivilege>, on target: GrantTarget, from user: DatabaseUser) -> [SQLStatement]
}

nonisolated extension UserManagementSQL {
    /// Groups `[schema, table?, privilege]` rows by target, keeping privileges the grid knows.
    func grants(from rows: [[String?]]) -> [GrantTarget: Set<TablePrivilege>] {
        var grants: [GrantTarget: Set<TablePrivilege>] = [:]
        for row in rows {
            guard row.count >= 3, let schema = row[0], let name = row[2].flatMap(TablePrivilege.init(catalogName:)) else { continue }
            let target: GrantTarget = (row[1]).map { .table(schema: schema, name: $0) } ?? .schema(schema)
            grants[target, default: []].insert(name)
        }
        return grants
    }

    /// Checks the name (and password) before building SQL.
    func validate(_ draft: UserDraft) throws {
        guard !draft.trimmedName.isEmpty else { throw UserManagementError.emptyName }
        guard draft.trimmedName.count <= capabilities.maxNameLength else {
            throw UserManagementError.nameTooLong(maximum: capabilities.maxNameLength)
        }
        guard ![draft.name, draft.host, draft.password].contains(where: { $0.contains("\0") }) else {
            throw UserManagementError.invalidCharacter
        }
    }

    /// "SELECT, INSERT" in a fixed order.
    func privilegeList(_ privileges: Set<TablePrivilege>) -> String {
        privileges.sorted().map(\.rawValue).joined(separator: ", ")
    }
}

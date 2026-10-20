import Foundation

/// An on/off setting of a database user. Which ones an engine supports is in
/// `UserManagementCapabilities`.
nonisolated enum UserOption: String, CaseIterable, Identifiable, Hashable, Sendable {
    /// Can sign in (PostgreSQL LOGIN; MySQL: the account isn't locked).
    case login
    /// Bypasses every permission check (PostgreSQL SUPERUSER).
    case superuser
    /// Can create databases (PostgreSQL CREATEDB).
    case createDatabases
    /// Can create, change and drop other users (PostgreSQL CREATEROLE).
    case createRoles

    var id: String { rawValue }
}

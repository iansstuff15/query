import Foundation

/// A database user (PostgreSQL role, or MySQL / MariaDB `user@host` account) and its options.
nonisolated struct DatabaseUser: Identifiable, Hashable, Sendable {
    let name: String
    /// The MySQL / MariaDB account's host (`%` for any); `nil` on engines without hosts.
    let host: String?
    var options: Set<UserOption>

    /// `name`, or `'name'@'host'` on engines with hosts.
    var id: String { host.map { "\(name)@\($0)" } ?? name }
}

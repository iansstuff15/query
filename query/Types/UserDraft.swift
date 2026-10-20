import Foundation

/// The user form: a new user, or changes to an existing one.
nonisolated struct UserDraft: Equatable, Sendable {
    var name: String
    /// MySQL / MariaDB only.
    var host: String
    /// Empty keeps the current password (or creates the user without one).
    var password: String
    var options: Set<UserOption>

    init(name: String = "", host: String = "%", password: String = "", options: Set<UserOption> = [.login]) {
        self.name = name
        self.host = host
        self.password = password
        self.options = options
    }

    init(user: DatabaseUser) {
        self.init(name: user.name, host: user.host ?? "%", password: "", options: user.options)
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    var trimmedHost: String {
        let host = host.trimmingCharacters(in: .whitespaces)
        return host.isEmpty ? "%" : host
    }
}

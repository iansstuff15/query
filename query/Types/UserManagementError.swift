import Foundation

/// Why a user form can't be saved, before anything is sent to the server.
nonisolated enum UserManagementError: Error, Equatable, Sendable {
    case emptyName
    case nameTooLong(maximum: Int)
    /// NUL characters can't be sent in SQL text.
    case invalidCharacter
}

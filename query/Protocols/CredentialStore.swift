import Foundation

/// Secure storage for runtime secrets such as database passwords.
nonisolated protocol CredentialStore: Sendable {
    func password(for account: String) -> String?
    /// Stores `password`, or removes the entry when it is empty.
    func setPassword(_ password: String, for account: String) throws
}

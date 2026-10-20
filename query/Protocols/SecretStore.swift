import Foundation

/// A credential store whose secrets can be listed and replaced as a whole, so they can move
/// between stores when the user switches (Keychain ↔ SQLite).
nonisolated protocol SecretStore: CredentialStore {
    /// Every secret, keyed by account. Throws when the store can't be read.
    func allSecrets() throws -> [String: String]
    /// Replaces every secret with `secrets` (an empty dictionary removes them all).
    func replaceAll(with secrets: [String: String]) throws
}

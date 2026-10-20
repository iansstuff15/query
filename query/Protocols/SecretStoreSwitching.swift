import Foundation

/// The app's active secret store, which the user can change during startup configuration or in
/// Settings.
nonisolated protocol SecretStoreSwitching: AnyObject, Sendable {
    var kind: SecretStoreKind { get }
    /// Moves every secret to `kind` and makes it active. Throws, leaving the current store
    /// active and untouched, when the secrets can't be read or written.
    func switchTo(_ kind: SecretStoreKind) throws
}

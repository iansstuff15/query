import Foundation

/// Raw generic-password items for one Keychain service, with errors reported (unlike
/// `CredentialStore`, which treats every failure as "no secret").
nonisolated protocol KeychainItemStoring: Sendable {
    /// The item's text, `nil` when there is no such item; throws when the Keychain refuses
    /// (for example, the user denied access).
    func read(_ account: String) throws -> String?
    /// Replaces the item, or removes it when `value` is empty.
    func write(_ value: String, for account: String) throws
    /// Account names of every item in the service. Reads attributes only, so it never prompts.
    func accounts() throws -> [String]
}

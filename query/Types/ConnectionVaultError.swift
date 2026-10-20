import Foundation

nonisolated enum ConnectionVaultError: Error, Equatable, Sendable {
    /// The encryption key could not be created or read from the Keychain.
    case keyUnavailable
    /// The data was not produced by this vault, or was tampered with.
    case corrupted
}

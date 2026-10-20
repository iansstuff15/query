import Foundation

nonisolated enum CredentialStoreError: Error, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
    /// The Keychain refused access earlier this launch (for example, the prompt was denied),
    /// so writes are refused rather than overwriting secrets that couldn't be read.
    case unavailable
}

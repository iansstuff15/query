import Foundation

nonisolated enum ConnectionArchiveError: Error, Equatable, Sendable {
    /// Not a query connection export, or a newer format version.
    case unsupportedFormat
    /// The export is encrypted and no passphrase was given.
    case passphraseRequired
    /// Decryption failed: wrong passphrase or modified file.
    case wrongPassphrase
    /// Passwords can only be exported encrypted.
    case passphraseTooShort
}

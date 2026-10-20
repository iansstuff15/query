import Foundation

/// On-disk shape of a connection export (`.json`).
///
/// Plain exports carry `connections` directly and never contain secrets. Encrypted exports
/// carry `ciphertext`: AES-256-GCM (combined nonce + ciphertext + tag, base64) of the JSON
/// connection list, keyed with PBKDF2-HMAC-SHA256(passphrase, `salt`, `iterations`).
nonisolated struct ConnectionArchiveEnvelope: Codable, Sendable {
    struct Encryption: Codable, Sendable {
        var cipher = "AES-256-GCM"
        var kdf = "PBKDF2-HMAC-SHA256"
        var iterations: Int
        var salt: String
    }

    static let formatName = "by-ian.query.connections"
    static let currentVersion = 1

    var format = formatName
    var version = currentVersion
    var exportedAt: Date
    var containsSecrets: Bool
    var encryption: Encryption?
    var ciphertext: String?
    var connections: [ConnectionExportEntry]?
}

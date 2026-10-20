import CryptoKit
import Foundation

/// Builds and reads connection exports. Secrets are only ever written encrypted.
nonisolated struct ConnectionArchive: Sendable {
    static let minimumPassphraseLength = 8

    var iterations = PassphraseKeyDerivation.defaultIterations
    var now: @Sendable () -> Date = Date.init

    /// - Parameter passphrase: required when `includeSecrets` is true; when `nil`, secrets
    ///   are stripped and the file is plain JSON.
    func export(_ entries: [ConnectionExportEntry], includeSecrets: Bool, passphrase: String?) throws -> Data {
        var envelope = ConnectionArchiveEnvelope(exportedAt: now(), containsSecrets: false)
        if let passphrase {
            guard passphrase.count >= Self.minimumPassphraseLength else { throw ConnectionArchiveError.passphraseTooShort }
            let payload = includeSecrets ? entries : entries.map(\.withoutSecrets)
            let salt = PassphraseKeyDerivation.randomSalt()
            let key = try PassphraseKeyDerivation.key(passphrase: passphrase, salt: salt, iterations: iterations)
            let sealed = try AES.GCM.seal(try Self.encoder.encode(payload), using: key, authenticating: Self.associatedData)
            guard let combined = sealed.combined else { throw ConnectionArchiveError.unsupportedFormat }
            envelope.containsSecrets = includeSecrets
            envelope.encryption = .init(iterations: iterations, salt: salt.base64EncodedString())
            envelope.ciphertext = combined.base64EncodedString()
        } else {
            guard !includeSecrets else { throw ConnectionArchiveError.passphraseTooShort }
            envelope.connections = entries.map(\.withoutSecrets)
        }
        return try Self.encoder.encode(envelope)
    }

    func isEncrypted(_ data: Data) throws -> Bool {
        try envelope(data).ciphertext != nil
    }

    func entries(from data: Data, passphrase: String?) throws -> [ConnectionExportEntry] {
        let envelope = try envelope(data)
        guard let ciphertext = envelope.ciphertext else { return envelope.connections ?? [] }
        guard let passphrase, !passphrase.isEmpty else { throw ConnectionArchiveError.passphraseRequired }
        guard let encryption = envelope.encryption, encryption.cipher == "AES-256-GCM", encryption.kdf == "PBKDF2-HMAC-SHA256",
              let salt = Data(base64Encoded: encryption.salt), let combined = Data(base64Encoded: ciphertext) else {
            throw ConnectionArchiveError.unsupportedFormat
        }
        let key = try PassphraseKeyDerivation.key(passphrase: passphrase, salt: salt, iterations: encryption.iterations)
        do {
            let plaintext = try AES.GCM.open(try AES.GCM.SealedBox(combined: combined), using: key, authenticating: Self.associatedData)
            return try JSONDecoder().decode([ConnectionExportEntry].self, from: plaintext)
        } catch {
            throw ConnectionArchiveError.wrongPassphrase
        }
    }

    private func envelope(_ data: Data) throws -> ConnectionArchiveEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let envelope = try? decoder.decode(ConnectionArchiveEnvelope.self, from: data),
              envelope.format == ConnectionArchiveEnvelope.formatName,
              envelope.version <= ConnectionArchiveEnvelope.currentVersion else {
            throw ConnectionArchiveError.unsupportedFormat
        }
        return envelope
    }

    /// Binds the ciphertext to this format so it can't be replayed into another context.
    private static let associatedData = Data(ConnectionArchiveEnvelope.formatName.utf8)

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

import CryptoKit
import Foundation
import os

/// AES-256-GCM with a random key generated on first use and kept in the Keychain
/// (this-device-only). Sealed blobs start with a version marker so plaintext rows written
/// by older builds can be recognized and migrated.
nonisolated final class KeychainConnectionCipher: ConnectionCipher, @unchecked Sendable {
    static let marker = Data("QV1".utf8)
    static let keyAccount = "connection-store-key"

    private let credentials: any CredentialStore
    private let lock = NSLock()
    private var cachedKey: SymmetricKey?

    init(credentials: any CredentialStore) {
        self.credentials = credentials
    }

    static func isSealed(_ data: Data) -> Bool {
        data.starts(with: marker)
    }

    func seal(_ plaintext: Data) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: try key())
        guard let combined = box.combined else { throw ConnectionVaultError.corrupted }
        return Self.marker + combined
    }

    func open(_ sealed: Data) throws -> Data {
        guard Self.isSealed(sealed) else { throw ConnectionVaultError.corrupted }
        do {
            let box = try AES.GCM.SealedBox(combined: sealed.dropFirst(Self.marker.count))
            return try AES.GCM.open(box, using: try key())
        } catch let error as ConnectionVaultError {
            throw error
        } catch {
            throw ConnectionVaultError.corrupted
        }
    }

    private func key() throws -> SymmetricKey {
        try lock.withLock {
            if let cachedKey { return cachedKey }
            if let stored = credentials.password(for: Self.keyAccount), let data = Data(base64Encoded: stored), data.count == 32 {
                let key = SymmetricKey(data: data)
                cachedKey = key
                return key
            }
            let key = SymmetricKey(size: .bits256)
            do {
                try credentials.setPassword(key.withUnsafeBytes { Data($0) }.base64EncodedString(), for: Self.keyAccount)
            } catch {
                AppLog.keychain.error("Creating the connection store key failed: \(String(describing: error), privacy: .private)")
                throw ConnectionVaultError.keyUnavailable
            }
            cachedKey = key
            return key
        }
    }
}

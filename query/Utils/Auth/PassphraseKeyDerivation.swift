import CommonCrypto
import CryptoKit
import Foundation

/// PBKDF2-HMAC-SHA256 key derivation (CommonCrypto) for passphrase-protected exports.
nonisolated enum PassphraseKeyDerivation {
    /// OWASP's 2023 recommendation for PBKDF2-HMAC-SHA256.
    static let defaultIterations = 600_000

    static func key(passphrase: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        var derived = [UInt8](repeating: 0, count: 32)
        let password = Array(passphrase.utf8)
        let status = salt.withUnsafeBytes { saltBytes in
            password.withUnsafeBufferPointer { passwordBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) }, passwordBytes.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations),
                    &derived, derived.count
                )
            }
        }
        guard status == kCCSuccess else { throw ConnectionArchiveError.unsupportedFormat }
        return SymmetricKey(data: derived)
    }

    static func randomSalt(byteCount: Int = 16) -> Data {
        SymmetricKey(size: SymmetricKeySize(bitCount: byteCount * 8)).withUnsafeBytes { Data($0) }
    }
}

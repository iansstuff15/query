import CryptoKit
import Foundation
import Testing
@testable import query

@Suite("ConnectionArchive")
struct ConnectionArchiveTests {
    private let archive = ConnectionArchive(iterations: 1_000, now: { Date(timeIntervalSince1970: 1_760_000_000) })
    private let entries = [
        ConnectionExportEntry(name: "Prod", engine: .postgreSQL, values: [.host: "db", .username: "ada", .password: "pw"]),
        ConnectionExportEntry(name: "Cache", engine: .redis, values: [.host: "cache", .password: "r"]),
    ]

    @Test func pbkdf2MatchesKnownSHA256Vector() throws {
        // PBKDF2-HMAC-SHA256("password", "salt", 1, 32) from RFC 7914 / common test vectors.
        let key = try PassphraseKeyDerivation.key(passphrase: "password", salt: Data("salt".utf8), iterations: 1)
        let hex = key.withUnsafeBytes { Data($0) }.map { String(format: "%02x", $0) }.joined()
        #expect(hex == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
    }

    @Test func plainExportNeverContainsSecrets() throws {
        let data = try archive.export(entries, includeSecrets: false, passphrase: nil)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("\"pw\""))
        #expect(text.contains("by-ian.query.connections"))
        #expect(try !archive.isEncrypted(data))
        let restored = try archive.entries(from: data, passphrase: nil)
        #expect(restored.map(\.name) == ["Prod", "Cache"])
        #expect(restored[0].values["password"] == nil)
        #expect(restored[0].values["host"] == "db")
    }

    @Test func secretsRequireAPassphrase() {
        #expect(throws: ConnectionArchiveError.passphraseTooShort) { try archive.export(entries, includeSecrets: true, passphrase: nil) }
        #expect(throws: ConnectionArchiveError.passphraseTooShort) { try archive.export(entries, includeSecrets: true, passphrase: "short") }
    }

    @Test func encryptedExportRoundTripsSecretsAndHidesEverything() throws {
        let data = try archive.export(entries, includeSecrets: true, passphrase: "correct horse")
        let text = String(decoding: data, as: UTF8.self)
        // Quoted, because base64 ciphertext can't contain quotes but can contain "pw" by chance.
        #expect(!text.contains(#""pw""#) && !text.contains(#""Prod""#) && !text.contains(#""cache""#))
        #expect(try archive.isEncrypted(data))
        #expect(try archive.entries(from: data, passphrase: "correct horse") == entries)
    }

    @Test func wrongMissingOrTamperedPassphraseFails() throws {
        let data = try archive.export(entries, includeSecrets: true, passphrase: "correct horse")
        #expect(throws: ConnectionArchiveError.passphraseRequired) { try archive.entries(from: data, passphrase: nil) }
        #expect(throws: ConnectionArchiveError.wrongPassphrase) { try archive.entries(from: data, passphrase: "battery staple") }
        var envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        var bytes = Data(base64Encoded: envelope["ciphertext"] as? String ?? "") ?? Data()
        bytes[bytes.startIndex + 20] ^= 0x01
        envelope["ciphertext"] = bytes.base64EncodedString()
        let tampered = try JSONSerialization.data(withJSONObject: envelope)
        #expect(throws: ConnectionArchiveError.wrongPassphrase) { try archive.entries(from: tampered, passphrase: "correct horse") }
    }

    @Test func rejectsForeignFiles() {
        #expect(throws: ConnectionArchiveError.unsupportedFormat) { try archive.entries(from: Data("{}".utf8), passphrase: nil) }
        #expect(throws: ConnectionArchiveError.unsupportedFormat) { try archive.entries(from: Data("not json".utf8), passphrase: nil) }
        let future = Data(#"{"format":"by-ian.query.connections","version":99,"exportedAt":"2026-01-01T00:00:00Z","containsSecrets":false}"#.utf8)
        #expect(throws: ConnectionArchiveError.unsupportedFormat) { try archive.entries(from: future, passphrase: nil) }
    }

    @Test func exportEntryDraftConversion() {
        let entry = ConnectionExportEntry(name: "x", engine: .mySQL, values: [.host: "h", .password: "p"])
        #expect(entry.draft == ConnectionDraft(engine: .mySQL, values: [.host: "h", .password: "p"]))
        #expect(entry.withoutSecrets.values == ["host": "h"])
    }
}

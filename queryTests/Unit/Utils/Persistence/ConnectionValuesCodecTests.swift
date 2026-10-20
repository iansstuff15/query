import Foundation
import Testing
@testable import query

@Suite("ConnectionValuesCodec")
struct ConnectionValuesCodecTests {
    private let codec = ConnectionValuesCodec(cipher: KeychainConnectionCipher(credentials: InMemoryCredentialStore()))

    @Test func dropsSecretsAndSeals() throws {
        let data = try codec.encode([.host: "db.internal", .password: "hunter2", .apiToken: "tok"])
        #expect(!String(decoding: data, as: UTF8.self).contains("db.internal"))
        let decoded = try codec.decode(data)
        #expect(decoded.values == [.host: "db.internal"])
        #expect(!decoded.wasPlaintext)
    }

    @Test func readsLegacyPlaintextRows() throws {
        let legacy = Data(#"{"host":"old.example","password":"leaked","port":"5432"}"#.utf8)
        let decoded = try codec.decode(legacy)
        #expect(decoded.values == [.host: "old.example", .port: "5432"])
        #expect(decoded.wasPlaintext)
    }
}

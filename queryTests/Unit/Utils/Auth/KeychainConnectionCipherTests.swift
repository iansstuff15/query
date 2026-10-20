import Foundation
import Testing
@testable import query

@Suite("KeychainConnectionCipher")
struct KeychainConnectionCipherTests {
    @Test func roundTripsAndMarksSealedData() throws {
        let cipher = KeychainConnectionCipher(credentials: InMemoryCredentialStore())
        let sealed = try cipher.seal(Data("host=db".utf8))
        #expect(KeychainConnectionCipher.isSealed(sealed))
        #expect(!sealed.contains(Data("host=db".utf8)))
        #expect(try cipher.open(sealed) == Data("host=db".utf8))
    }

    @Test func keyIsCreatedOnceAndReusedFromTheKeychain() throws {
        let store = InMemoryCredentialStore()
        let sealed = try KeychainConnectionCipher(credentials: store).seal(Data("x".utf8))
        let storedKey = try #require(store.password(for: KeychainConnectionCipher.keyAccount))
        #expect(Data(base64Encoded: storedKey)?.count == 32)
        #expect(try KeychainConnectionCipher(credentials: store).open(sealed) == Data("x".utf8))
    }

    @Test func differentKeyOrTamperingIsRejected() throws {
        let sealed = try KeychainConnectionCipher(credentials: InMemoryCredentialStore()).seal(Data("secret".utf8))
        #expect(throws: ConnectionVaultError.corrupted) {
            try KeychainConnectionCipher(credentials: InMemoryCredentialStore()).open(sealed)
        }
        var tampered = sealed
        tampered[tampered.index(before: tampered.endIndex)] ^= 0xFF
        let cipher = KeychainConnectionCipher(credentials: InMemoryCredentialStore())
        #expect(throws: ConnectionVaultError.corrupted) { try cipher.open(Data("{}".utf8)) }
        #expect(throws: ConnectionVaultError.corrupted) { try cipher.open(tampered) }
    }

    @Test func missingKeychainFailsClosed() {
        let cipher = KeychainConnectionCipher(credentials: InMemoryCredentialStore(failsOnWrite: true))
        #expect(throws: ConnectionVaultError.keyUnavailable) { try cipher.seal(Data("x".utf8)) }
    }
}

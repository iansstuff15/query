import Foundation
import Synchronization
import Testing
@testable import query

/// A store that can't be read, like a Keychain whose prompt was denied.
final class UnreadableSecretStore: SecretStore, @unchecked Sendable {
    func password(for account: String) -> String? { nil }
    func setPassword(_ password: String, for account: String) throws { throw CredentialStoreError.unavailable }
    func allSecrets() throws -> [String: String] { throw CredentialStoreError.unavailable }
    func replaceAll(with secrets: [String: String]) throws { throw CredentialStoreError.unavailable }
}

@Suite("SwitchableCredentialStore")
struct SwitchableCredentialStoreTests {
    @Test func forwardsToTheActiveStore() throws {
        let sqlite = EphemeralCredentialStore()
        let keychain = EphemeralCredentialStore()
        let store = SwitchableCredentialStore(stores: [.sqlite: sqlite, .keychain: keychain], active: .sqlite)
        try store.setPassword("pw", for: "a")
        #expect(store.password(for: "a") == "pw")
        #expect(sqlite.password(for: "a") == "pw")
        #expect(keychain.password(for: "a") == nil)
    }

    @Test func switchingMovesEverySecretAndClearsTheOldStore() throws {
        let sqlite = EphemeralCredentialStore()
        let keychain = EphemeralCredentialStore()
        let saved = Mutex<[SecretStoreKind]>([])
        let store = SwitchableCredentialStore(
            stores: [.sqlite: sqlite, .keychain: keychain], active: .sqlite, onSwitch: { kind in saved.withLock { $0.append(kind) } }
        )
        try store.setPassword("key", for: "connection-store-key")
        try store.setPassword("pw", for: "A.password")
        try store.switchTo(.keychain)
        #expect(store.kind == .keychain)
        #expect(try keychain.allSecrets() == ["connection-store-key": "key", "A.password": "pw"])
        #expect(try sqlite.allSecrets().isEmpty)
        #expect(store.password(for: "connection-store-key") == "key")
        #expect(saved.withLock { $0 } == [.keychain])
    }

    @Test func switchingToTheActiveStoreDoesNothing() throws {
        let saved = Mutex(0)
        let store = SwitchableCredentialStore(
            stores: [.sqlite: EphemeralCredentialStore(), .keychain: UnreadableSecretStore()], active: .sqlite,
            onSwitch: { _ in saved.withLock { $0 += 1 } }
        )
        try store.switchTo(.sqlite)
        #expect(saved.withLock { $0 } == 0)
    }

    @Test func anUnreadableSourceLeavesEverythingAsItWas() throws {
        let sqlite = EphemeralCredentialStore()
        let store = SwitchableCredentialStore(stores: [.sqlite: sqlite, .keychain: UnreadableSecretStore()], active: .keychain)
        #expect(throws: CredentialStoreError.unavailable) { try store.switchTo(.sqlite) }
        #expect(store.kind == .keychain)
        #expect(try sqlite.allSecrets().isEmpty)
    }

    @Test func anUnwritableDestinationKeepsTheSecretsWhereTheyWere() throws {
        let sqlite = EphemeralCredentialStore()
        try sqlite.setPassword("key", for: "connection-store-key")
        let store = SwitchableCredentialStore(stores: [.sqlite: sqlite, .keychain: UnreadableSecretStore()], active: .sqlite)
        #expect(throws: CredentialStoreError.unavailable) { try store.switchTo(.keychain) }
        #expect(store.kind == .sqlite)
        #expect(sqlite.password(for: "connection-store-key") == "key")
    }
}

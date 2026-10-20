import Foundation
import Testing
@testable import query

/// In-memory Keychain items that count reads and can refuse them like a denied prompt.
private final class FakeKeychainItems: KeychainItemStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String]
    private let refusesReads: Bool
    private(set) var reads: [String] = []

    init(_ values: [String: String] = [:], refusesReads: Bool = false) {
        self.values = values
        self.refusesReads = refusesReads
    }

    var stored: [String: String] { lock.withLock { values } }
    var readCount: Int { lock.withLock { reads.count } }

    func read(_ account: String) throws -> String? {
        try lock.withLock {
            reads.append(account)
            if refusesReads { throw CredentialStoreError.unexpectedStatus(-128) }
            return values[account]
        }
    }

    func write(_ value: String, for account: String) throws {
        lock.withLock { values[account] = value.isEmpty ? nil : value }
    }

    func accounts() throws -> [String] {
        lock.withLock { Array(values.keys) }
    }
}

@Suite("KeychainVaultCredentialStore")
struct KeychainVaultCredentialStoreTests {
    private func vault(_ items: FakeKeychainItems) throws -> [String: String] {
        let json = try #require(items.stored[KeychainVaultCredentialStore.vaultAccount])
        return try JSONDecoder().decode([String: String].self, from: Data(json.utf8))
    }

    @Test func keepsEverySecretInOneItem() throws {
        let items = FakeKeychainItems()
        let store = KeychainVaultCredentialStore(items: items)
        try store.setPassword("key", for: "connection-store-key")
        try store.setPassword("pw", for: "A.password")
        #expect(Array(items.stored.keys) == [KeychainVaultCredentialStore.vaultAccount])
        #expect(try vault(items) == ["connection-store-key": "key", "A.password": "pw"])
        try store.setPassword("", for: "A.password")
        #expect(store.password(for: "A.password") == nil)
        #expect(try vault(items) == ["connection-store-key": "key"])
    }

    @Test func readsTheKeychainOncePerLaunch() throws {
        let items = FakeKeychainItems([KeychainVaultCredentialStore.vaultAccount: #"{"a":"1","b":"2"}"#])
        let store = KeychainVaultCredentialStore(items: items)
        #expect(store.password(for: "a") == "1")
        #expect(store.password(for: "b") == "2")
        #expect(store.password(for: "missing") == nil)
        try store.setPassword("3", for: "c")
        #expect(items.readCount == 1)
        // A fresh launch sees the write.
        #expect(KeychainVaultCredentialStore(items: items).password(for: "c") == "3")
    }

    @Test func movesItemsFromEarlierBuildsIntoTheVault() throws {
        let items = FakeKeychainItems(["connection-store-key": "key", "A.password": "pw"])
        let store = KeychainVaultCredentialStore(items: items)
        #expect(store.password(for: "connection-store-key") == "key")
        #expect(store.password(for: "A.password") == "pw")
        #expect(Array(items.stored.keys) == [KeychainVaultCredentialStore.vaultAccount])
        #expect(try vault(items) == ["connection-store-key": "key", "A.password": "pw"])
    }

    @Test func aRefusedReadNeverOverwritesSecrets() {
        let items = FakeKeychainItems([KeychainVaultCredentialStore.vaultAccount: #"{"connection-store-key":"key"}"#], refusesReads: true)
        let store = KeychainVaultCredentialStore(items: items)
        #expect(store.password(for: "connection-store-key") == nil)
        #expect(throws: CredentialStoreError.unavailable) { try store.setPassword("new", for: "connection-store-key") }
        #expect(items.stored[KeychainVaultCredentialStore.vaultAccount] == #"{"connection-store-key":"key"}"#)
        // Doesn't keep asking after a refusal.
        _ = store.password(for: "other")
        #expect(items.readCount == 1)
    }

    @Test func theConnectionKeyIsntReplacedWhenTheKeychainRefuses() {
        let items = FakeKeychainItems([KeychainVaultCredentialStore.vaultAccount: #"{"connection-store-key":"key"}"#], refusesReads: true)
        let cipher = KeychainConnectionCipher(credentials: KeychainVaultCredentialStore(items: items))
        #expect(throws: ConnectionVaultError.keyUnavailable) { try cipher.seal(Data("x".utf8)) }
        #expect(items.stored[KeychainVaultCredentialStore.vaultAccount] == #"{"connection-store-key":"key"}"#)
    }

    @Test func anUnreadableVaultIsLeftAlone() {
        let items = FakeKeychainItems([KeychainVaultCredentialStore.vaultAccount: "not json"])
        let store = KeychainVaultCredentialStore(items: items)
        #expect(store.password(for: "a") == nil)
        #expect(throws: CredentialStoreError.unavailable) { try store.setPassword("1", for: "a") }
        #expect(items.stored[KeychainVaultCredentialStore.vaultAccount] == "not json")
    }
}

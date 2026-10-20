import Foundation
import Testing
@testable import query

@Suite("KeychainCredentialStore", .tags(.integration))
struct KeychainCredentialStoreTests {
    @Test func storesReplacesAndDeletes() throws {
        let store = KeychainCredentialStore(service: "by-ian.query.tests.\(UUID().uuidString)")
        let account = "me@db:5432/app"
        defer { try? store.setPassword("", for: account) }

        #expect(store.password(for: account) == nil)
        try store.setPassword("first", for: account)
        #expect(store.password(for: account) == "first")
        try store.setPassword("second", for: account)
        #expect(store.password(for: account) == "second")
        try store.setPassword("", for: account)
        #expect(store.password(for: account) == nil)
    }

    @Test func vaultMigratesSeparateItemsIntoOne() throws {
        let items = KeychainCredentialStore(service: "by-ian.query.tests.\(UUID().uuidString)")
        defer { try? items.setPassword("", for: KeychainVaultCredentialStore.vaultAccount) }
        try items.setPassword("key", for: "connection-store-key")
        try items.setPassword("pw", for: "A.password")
        #expect(Set(try items.accounts()) == ["connection-store-key", "A.password"])

        let vault = KeychainVaultCredentialStore(items: items)
        #expect(vault.password(for: "A.password") == "pw")
        try vault.setPassword("pw2", for: "B.password")
        #expect(try items.accounts() == [KeychainVaultCredentialStore.vaultAccount])
        let relaunched = KeychainVaultCredentialStore(items: items)
        #expect(relaunched.password(for: "connection-store-key") == "key")
        #expect(relaunched.password(for: "B.password") == "pw2")
    }
}

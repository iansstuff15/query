import Foundation
import SwiftData
import Testing
@testable import query

/// Encrypted persistence against a fresh in-memory SwiftData store.
@MainActor
@Suite("SwiftDataConnectionStore", .tags(.integration))
struct SwiftDataConnectionStoreTests {
    private let container: ModelContainer
    private let credentials = InMemoryCredentialStore()
    private let store: SwiftDataConnectionStore

    init() throws {
        container = try ModelContainer(for: SavedConnection.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = SwiftDataConnectionStore(
            context: container.mainContext, credentials: credentials, cipher: KeychainConnectionCipher(credentials: credentials)
        )
    }

    private func rows() throws -> [SavedConnection] {
        try container.mainContext.fetch(FetchDescriptor<SavedConnection>())
    }

    @Test func rowsAreEncryptedAndSecretsStayInTheKeychain() throws {
        let draft = ConnectionDraft(engine: .postgreSQL, values: [.host: "prod.db.internal", .username: "ada", .password: "hunter2"])
        let id = try store.save(draft, name: "Prod", id: nil, rememberSecrets: true)
        let row = try #require(try rows().first)
        let raw = String(decoding: row.valuesJSON, as: UTF8.self)
        #expect(KeychainConnectionCipher.isSealed(row.valuesJSON))
        #expect(!raw.contains("prod.db.internal") && !raw.contains("ada") && !raw.contains("hunter2"))
        #expect(credentials.password(for: SwiftDataConnectionStore.account(id, .password)) == "hunter2")
        #expect(store.draft(for: row) == draft)
    }

    @Test func forgettingSecretsRemovesThem() throws {
        let draft = ConnectionDraft(engine: .redis, values: [.host: "cache", .password: "pw"])
        let id = try store.save(draft, name: "Cache", id: nil, rememberSecrets: true)
        try store.save(draft, name: "Cache", id: id, rememberSecrets: false)
        #expect(try rows().count == 1)
        #expect(credentials.password(for: SwiftDataConnectionStore.account(id, .password)) == nil)
    }

    @Test func legacyPlaintextRowsAreMigratedOnRead() throws {
        let legacy = SavedConnection(name: "Old", engine: .mySQL, sealedValues: Data(#"{"host":"legacy.example"}"#.utf8), date: .now)
        container.mainContext.insert(legacy)
        try container.mainContext.save()
        #expect(store.draft(for: legacy).values[.host] == "legacy.example")
        #expect(KeychainConnectionCipher.isSealed(legacy.valuesJSON))
        #expect(store.draft(for: legacy).values[.host] == "legacy.example")
    }

    @Test func exportImportRoundTripThroughEncryptedArchive() throws {
        try store.save(ConnectionDraft(engine: .postgreSQL, values: [.host: "db", .password: "pw"]), name: "Prod", id: nil, rememberSecrets: true)
        let archive = ConnectionArchive(iterations: 1_000)
        let file = try archive.export(try store.exportEntries(), includeSecrets: true, passphrase: "long enough")

        let otherCredentials = InMemoryCredentialStore()
        let otherContainer = try ModelContainer(for: SavedConnection.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let other = SwiftDataConnectionStore(
            context: otherContainer.mainContext, credentials: otherCredentials, cipher: KeychainConnectionCipher(credentials: otherCredentials)
        )
        #expect(try other.importEntries(try archive.entries(from: file, passphrase: "long enough")) == 1)
        let imported = try #require(try otherContainer.mainContext.fetch(FetchDescriptor<SavedConnection>()).first)
        #expect(imported.name == "Prod")
        #expect(other.draft(for: imported).values == [.host: "db", .password: "pw"])
    }

    @Test func deleteRemovesRowAndSecrets() throws {
        let id = try store.save(ConnectionDraft(engine: .snowflake, values: [.account: "a", .apiToken: "t"]), name: "SF", id: nil, rememberSecrets: true)
        try store.delete(try #require(try rows().first))
        #expect(try rows().isEmpty)
        #expect(credentials.password(for: SwiftDataConnectionStore.account(id, .apiToken)) == nil)
    }
}

import Foundation
import Testing
@testable import query

@Suite("SQLiteCredentialStore", .tags(.integration))
struct SQLiteCredentialStoreTests {
    private let fileURL = FileManager.default.temporaryDirectory.appending(path: "secrets-\(UUID().uuidString).sqlite")

    @Test func storesReplacesDeletesAndPersists() throws {
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = SQLiteCredentialStore(fileURL: fileURL)
        #expect(store.password(for: "a") == nil)
        try store.setPassword("first", for: "a")
        try store.setPassword("second", for: "a")
        try store.setPassword("pw'; DROP TABLE secrets; --", for: "b")
        #expect(store.password(for: "a") == "second")
        try store.setPassword("", for: "a")
        #expect(store.password(for: "a") == nil)
        // A new launch reads the same file.
        #expect(SQLiteCredentialStore(fileURL: fileURL).password(for: "b") == "pw'; DROP TABLE secrets; --")
        let permissions = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
    }

    @Test func listsAndReplacesEverything() throws {
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = SQLiteCredentialStore(fileURL: fileURL)
        try store.replaceAll(with: ["key": "k", "A.password": "pw", "empty": ""])
        #expect(try store.allSecrets() == ["key": "k", "A.password": "pw"])
        try store.replaceAll(with: [:])
        #expect(try store.allSecrets().isEmpty)
    }
}

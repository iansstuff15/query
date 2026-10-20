import Testing
@testable import query

@Suite("EngineCatalog")
struct EngineCatalogTests {
    @Test func coversEveryTablePlusEngine() {
        #expect(EngineCatalog.all.count == 21)
        #expect(Set(EngineCatalog.all.map(\.engine)) == Set(DatabaseEngine.allCases))
    }

    @Test(arguments: DatabaseEngine.allCases)
    func descriptorsAreConsistent(engine: DatabaseEngine) {
        let descriptor = EngineCatalog.descriptor(for: engine)
        #expect(!descriptor.fields.isEmpty)
        #expect(!descriptor.displayName.isEmpty)
        #expect(descriptor.requiredFields.allSatisfy(descriptor.fields.contains))
        if descriptor.isURLFirst { #expect(descriptor.fields.contains(.url)) }
        if descriptor.fields.contains(.port) { #expect(descriptor.defaultPort != nil) }
    }

    @Test func secretsAreFlagged() {
        #expect(ConnectionField.allCases.filter(\.isSecret) == [.password, .serviceAccountJSON, .secretAccessKey, .apiToken])
    }

    @Test func draftSplitsSecrets() {
        let draft = ConnectionDraft(engine: .postgreSQL, values: [.host: "h", .password: "p"])
        #expect(draft.nonSecretValues == [.host: "h"])
        #expect(draft.secretValues == [.password: "p"])
    }
}

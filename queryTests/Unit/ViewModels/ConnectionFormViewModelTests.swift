import Foundation
import Testing
@testable import query

@MainActor
final class RecordingConnectionStore: ConnectionStore {
    private(set) var saved: [(ConnectionDraft, String, Bool)] = []

    func save(_ draft: ConnectionDraft, name: String, id: UUID?, rememberSecrets: Bool) throws -> UUID {
        saved.append((draft, name, rememberSecrets))
        return id ?? UUID()
    }

    func draft(for connection: SavedConnection) -> ConnectionDraft { ConnectionDraft(engine: connection.engine ?? .postgreSQL) }
    func delete(_ connection: SavedConnection) throws {}
    var entries: [ConnectionExportEntry] = []
    private(set) var imported: [ConnectionExportEntry] = []
    func exportEntries() throws -> [ConnectionExportEntry] { entries }
    func importEntries(_ entries: [ConnectionExportEntry]) throws -> Int {
        imported += entries
        return entries.count
    }
}

struct FailingFactory: DatabaseClientFactory {
    func makeClient(for draft: ConnectionDraft) throws -> any DatabaseClient { throw DatabaseError.missingConfiguration }
}

@MainActor
@Suite("ConnectionFormViewModel")
struct ConnectionFormViewModelTests {
    @Test func newFormStartsWithEngineDefaults() {
        let model = ConnectionFormViewModel(engine: .mySQL, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore())
        #expect(model.draft[.host] == "localhost")
        #expect(model.draft[.port] == "3306")
        #expect(model.draft[.username] == "root")
        #expect(model.canConnect)
        #expect(model.displayName == "localhost")
    }

    @Test func importFillsFieldsAndFlagsInvalidInput() {
        let model = ConnectionFormViewModel(engine: .postgreSQL, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore())
        model.connectionString = "postgres://ada:pw@db:6543/app"
        model.importConnectionString()
        #expect(model.importResult == .imported)
        #expect(model.draft[.host] == "db")
        #expect(model.draft[.password] == "pw")
        model.connectionString = "mysql://nope"
        model.importConnectionString()
        #expect(model.importResult == .invalid)
    }

    @Test func urlFirstEnginesHideTheURLField() {
        let model = ConnectionFormViewModel(engine: .mongoDB, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore())
        #expect(!model.visibleFields.contains(.url))
        #expect(model.canConnect)
        let sqlite = ConnectionFormViewModel(engine: .sqlite, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore())
        #expect(!sqlite.canConnect)
    }

    @Test func testReportsObjectCount() async {
        let model = ConnectionFormViewModel(engine: .postgreSQL, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore())
        await model.test()
        #expect(model.testState.value == SampleCatalog.objects.count)
    }

    @Test func testFailureIsSilentState() async {
        let model = ConnectionFormViewModel(engine: .postgreSQL, factory: StubDatabaseClientFactory(scenario: .failing), store: RecordingConnectionStore())
        await model.test()
        guard case .failed = model.testState else {
            Issue.record("Expected failed state")
            return
        }
    }

    @Test func connectSavesAndReturnsSession() async throws {
        let store = RecordingConnectionStore()
        let model = ConnectionFormViewModel(engine: .postgreSQL, factory: StubDatabaseClientFactory(), store: store)
        model.name = "Local"
        model.draft[.password] = "pw"
        let session = try #require(await model.connect())
        #expect(session.name == "Local")
        #expect(session.engine == .postgreSQL)
        #expect(store.saved.count == 1)
        #expect(store.saved.first?.0.values[.password] == "pw")
        #expect(!model.isConnecting)
    }

    @Test func saveStoresWithoutConnectingAndReusesTheID() throws {
        let store = RecordingConnectionStore()
        let model = ConnectionFormViewModel(engine: .sqlite, factory: FailingFactory(), store: store)
        model.draft[.filePath] = "/tmp/app.sqlite"
        model.save()
        model.save()
        #expect(model.didSave)
        #expect(store.saved.count == 2)
        #expect(store.saved.first?.1 == "app.sqlite")
    }

    @Test func connectFailureReturnsNilWithoutSaving() async {
        let store = RecordingConnectionStore()
        let model = ConnectionFormViewModel(engine: .postgreSQL, factory: FailingFactory(), store: store)
        #expect(await model.connect() == nil)
        #expect(store.saved.isEmpty)
    }

    // MARK: - Connection string without Import

    @Test func typingAConnectionStringFillsFieldsWithoutImport() {
        let model = ConnectionFormViewModel(engine: .postgreSQL, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore())
        model.connectionStringInput = "postgresql://query_reader:ReaderPass1@localhost:55432/app?sslmode=disable"
        #expect(model.importResult == .imported)
        #expect(model.draft[.username] == "query_reader")
        #expect(model.draft[.password] == "ReaderPass1")
        #expect(model.draft[.port] == "55432")
        #expect(model.draft[.database] == "app")
    }

    @Test func partialInputStaysQuietUntilItParses() {
        let model = ConnectionFormViewModel(engine: .mySQL, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore())
        model.connectionStringInput = "mysq"
        #expect(model.importResult == .none)
        #expect(model.draft[.host] == "localhost")
    }

    @Test func partsRemovedFromTheStringFallBackToDefaults() {
        let model = ConnectionFormViewModel(engine: .postgreSQL, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore())
        model.connectionStringInput = "postgres://ada:pw@db:6543/app"
        model.connectionStringInput = "postgres://ada@db/app"
        #expect(model.draft[.port] == "5432")
        #expect(model.draft[.password].isEmpty)
        #expect(model.draft[.host] == "db")
    }

    @Test func connectUsesTheTypedStringAndKeepsLaterManualEdits() async throws {
        let store = RecordingConnectionStore()
        let model = ConnectionFormViewModel(engine: .mySQL, factory: StubDatabaseClientFactory(), store: store)
        model.connectionStringInput = "mysql://query_writer:WriterPass1@localhost:33306/app"
        model.draft[.database] = "sales"
        _ = try #require(await model.connect())
        let saved = try #require(store.saved.first?.0)
        #expect(saved.values[.username] == "query_writer")
        #expect(saved.values[.port] == "33306")
        #expect(saved.values[.database] == "sales")
    }

    @Test func urlFirstEnginesApplyTheURLBeforeTesting() async {
        let model = ConnectionFormViewModel(engine: .elasticsearch, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore())
        model.connectionStringInput = "http://query_reader:ReaderPass1@localhost:19200"
        // Not rewritten mid-typing.
        #expect(model.draft[.url] == "http://query_reader:ReaderPass1@localhost:19200")
        await model.test()
        #expect(model.draft[.url] == "http://localhost:19200")
        #expect(model.draft[.username] == "query_reader")
        #expect(model.draft[.password] == "ReaderPass1")
        #expect(model.importResult == .none)
        #expect(model.testState.value != nil)
    }

    // MARK: - Clipboard

    @Test func newFormPicksUpAConnectionStringFromTheClipboard() {
        let clipboard = FakeClipboard("mysql://query_reader:ReaderPass1@localhost:33306/app")
        let model = ConnectionFormViewModel(
            engine: .mySQL, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore(), clipboard: clipboard
        )
        model.pickUpClipboard()
        #expect(model.importResult == .pasted)
        #expect(model.connectionStringInput == "mysql://query_reader:ReaderPass1@localhost:33306/app")
        #expect(model.draft[.port] == "33306")
        #expect(model.draft[.username] == "query_reader")
    }

    @Test func urlFirstFormPicksUpTheClipboardIntoTheURLField() {
        let clipboard = FakeClipboard("mongodb://query_reader:ReaderPass1@localhost:27018/app?authSource=app")
        let model = ConnectionFormViewModel(
            engine: .mongoDB, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore(), clipboard: clipboard
        )
        model.pickUpClipboard()
        #expect(model.importResult == .pasted)
        #expect(model.draft[.url] == "mongodb://query_reader:ReaderPass1@localhost:27018/app?authSource=app")
    }

    @Test(arguments: ["postgres://ada@db:5432/app", "just some copied text", "/Users/me/notes.txt"])
    func clipboardTextThatIsntAConnectionStringIsIgnored(text: String) {
        let model = ConnectionFormViewModel(
            engine: .mySQL, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore(), clipboard: FakeClipboard(text)
        )
        model.pickUpClipboard()
        #expect(model.importResult == .none)
        #expect(model.connectionString.isEmpty)
        #expect(model.draft[.host] == "localhost")
    }

    @Test func clipboardIsLeftAloneOnceTheFormIsEditedOrSaved() {
        let edited = FakeClipboard("mysql://root@db:3306/app")
        let model = ConnectionFormViewModel(
            engine: .mySQL, factory: StubDatabaseClientFactory(), store: RecordingConnectionStore(), clipboard: edited
        )
        model.draft[.host] = "typed.by.hand"
        model.pickUpClipboard()
        #expect(model.draft[.host] == "typed.by.hand")
        #expect(edited.reads == 0)

        let reopenedClipboard = FakeClipboard("mysql://root@db:3306/app")
        let reopened = ConnectionFormViewModel(
            draft: ConnectionDraft(engine: .mySQL, values: [.host: "saved"]), name: "Saved", savedID: UUID(),
            factory: StubDatabaseClientFactory(), store: RecordingConnectionStore(), clipboard: reopenedClipboard
        )
        reopened.pickUpClipboard()
        #expect(reopened.draft[.host] == "saved")
        #expect(reopenedClipboard.reads == 0)
    }
}

@MainActor
@Suite("WelcomeViewModel")
struct WelcomeViewModelTests {
    @Test func listsEveryEngineAndFiltersFuzzily() {
        let model = WelcomeViewModel(factory: StubDatabaseClientFactory(), store: RecordingConnectionStore())
        #expect(model.engines.count == DatabaseEngine.allCases.count)
        model.query = "pg"
        #expect(model.engines.isEmpty == false)
        model.query = "mongo"
        #expect(model.engines.first?.engine == .mongoDB)
        model.query = "zzzz"
        #expect(model.engines.isEmpty)
    }

    @Test func choosingAnEnginePresentsItsForm() {
        let model = WelcomeViewModel(factory: StubDatabaseClientFactory(), store: RecordingConnectionStore())
        model.choose(.oracle)
        #expect(model.presentedForm?.descriptor.engine == .oracle)
        #expect(model.presentedForm?.draft[.serviceName] == "FREEPDB1")
    }

    @Test func presentedFormReadsTheInjectedClipboard() {
        let model = WelcomeViewModel(
            factory: StubDatabaseClientFactory(), store: RecordingConnectionStore(), clipboard: FakeClipboard("mysql://root@db:3306/app")
        )
        model.choose(.mySQL)
        model.presentedForm?.pickUpClipboard()
        #expect(model.presentedForm?.draft[.host] == "db")
    }
}

@MainActor
@Suite("SessionViewModel")
struct SessionViewModelTests {
    @Test func openAndDisconnect() async {
        let model = SessionViewModel()
        model.open(ConnectionSession(id: UUID(), name: "x", engine: .redis, client: MockDatabaseClient()))
        #expect(model.session?.name == "x")
        await model.disconnect()
        #expect(model.session == nil)
    }
}

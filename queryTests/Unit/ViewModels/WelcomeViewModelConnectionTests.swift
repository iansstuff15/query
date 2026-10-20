import Foundation
import Testing
@testable import query

/// Saved connections whose drafts point at named hosts.
@MainActor
private final class HostConnectionStore: ConnectionStore {
    private(set) var saved: [(ConnectionDraft, String, UUID?, Bool)] = []
    private var drafts: [UUID: ConnectionDraft] = [:]

    func add(_ name: String, host: String, secret: String? = nil) -> SavedConnection {
        let connection = SavedConnection(name: name, engine: .postgreSQL, sealedValues: Data(), date: .distantPast)
        var draft = ConnectionDraft(engine: .postgreSQL, values: [.host: host])
        draft[.password] = secret ?? ""
        drafts[connection.id] = draft
        return connection
    }

    func save(_ draft: ConnectionDraft, name: String, id: UUID?, rememberSecrets: Bool) throws -> UUID {
        saved.append((draft, name, id, rememberSecrets))
        return id ?? UUID()
    }

    func draft(for connection: SavedConnection) -> ConnectionDraft { drafts[connection.id] ?? ConnectionDraft(engine: .postgreSQL) }
    func delete(_ connection: SavedConnection) throws {}
    func exportEntries() throws -> [ConnectionExportEntry] { [] }
    func importEntries(_ entries: [ConnectionExportEntry]) throws -> Int { 0 }
}

/// `up` answers, `down` refuses, `hang` never answers, anything else has no driver.
private struct HostFactory: DatabaseClientFactory {
    let hang = Gate()

    func makeClient(for draft: ConnectionDraft) throws -> any DatabaseClient {
        switch draft[.host] {
        case "up": MockDatabaseClient()
        case "down": MockDatabaseClient(objects: .failure(MockError()))
        case "hang": MockDatabaseClient(gate: hang)
        default: throw DatabaseError.missingConfiguration
        }
    }
}

@MainActor
@Suite("WelcomeViewModel recent connections")
struct WelcomeViewModelConnectionTests {
    private let store = HostConnectionStore()

    private func model(timeout: Duration = .seconds(5)) -> WelcomeViewModel {
        WelcomeViewModel(factory: HostFactory(), store: store, checkTimeout: timeout)
    }

    @Test func healthCheckMarksEachConnection() async {
        let up = store.add("Up", host: "up")
        let down = store.add("Down", host: "down")
        let broken = store.add("Broken", host: "nowhere")
        let model = model()
        #expect(model.health(of: up) == .unknown)
        await model.checkHealth(of: [up, down, broken])
        #expect(model.health(of: up) == .reachable)
        #expect(model.health(of: down) == .unreachable)
        #expect(model.health(of: broken) == .unreachable)
    }

    @Test func aServerThatNeverAnswersTimesOut() async {
        let hanging = store.add("Hanging", host: "hang")
        let model = model(timeout: .milliseconds(20))
        await model.checkHealth(of: [hanging])
        #expect(model.health(of: hanging) == .unreachable)
    }

    @Test func connectOpensASessionAndKeepsRememberedSecrets() async throws {
        let up = store.add("Local", host: "up", secret: "pw")
        let model = model()
        let session = try #require(await model.connect(up))
        #expect(session.id == up.id)
        #expect(session.name == "Local")
        #expect(session.engine == .postgreSQL)
        #expect(model.connectingID == nil)
        #expect(model.health(of: up) == .reachable)
        let saved = try #require(store.saved.first)
        #expect(saved.2 == up.id)
        #expect(saved.3)
    }

    @Test func connectWithoutStoredSecretsDoesntStartRememberingThem() async throws {
        let up = store.add("Local", host: "up")
        _ = try #require(await model().connect(up))
        #expect(store.saved.first?.3 == false)
    }

    @Test func failedConnectMarksTheConnectionUnreachable() async {
        let down = store.add("Down", host: "down")
        let model = model()
        #expect(await model.connect(down) == nil)
        #expect(model.health(of: down) == .unreachable)
        #expect(store.saved.isEmpty)
    }

    @Test func unreachableConnectionsDontOpen() async {
        let flaky = store.add("Flaky", host: "down")
        let model = model()
        await model.checkHealth(of: [flaky])
        #expect(!model.health(of: flaky).canOpen)
        #expect(await model.connect(flaky) == nil)
    }

    @Test func editingOpensTheSheetForThatConnection() {
        let up = store.add("Local", host: "up")
        let model = model()
        model.reopen(up)
        #expect(model.presentedForm?.draft[.host] == "up")
        #expect(model.presentedForm?.name == "Local")
    }

    @Test func deletingForgetsItsHealth() async {
        let up = store.add("Local", host: "up")
        let model = model()
        await model.checkHealth(of: [up])
        model.delete(up)
        #expect(model.health(of: up) == .unknown)
    }

    @Test func healthChecksCanBeTurnedOff() async {
        let down = store.add("Down", host: "down")
        let model = WelcomeViewModel(factory: HostFactory(), store: store, checksHealth: false)
        await model.checkHealth(of: [down])
        #expect(model.health(of: down) == .unknown)
        #expect(model.health(of: down).canOpen)
    }
}

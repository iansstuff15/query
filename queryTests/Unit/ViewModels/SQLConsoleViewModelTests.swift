import Foundation
import Testing
@testable import query

/// Fails every statement with a server message, like Postgres / MySQL do.
private struct SQLErrorClient: SQLConsoleRunning {
    let message: String

    func runSQL(_ sql: String) async throws -> QueryResult { throw DatabaseError.statementFailed(message) }
    func listObjects() async throws -> [DatabaseObject] { [] }
    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] { [] }
    func rows(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) async throws -> QueryResult {
        QueryResult(columns: columns, values: [])
    }
}

@MainActor
@Suite("SQLConsoleViewModel")
struct SQLConsoleViewModelTests {
    private let connectionID = UUID()
    private let ranAt = Date(timeIntervalSince1970: 1_768_035_600)

    private func console(
        _ client: any DatabaseClient, text: String, step: Duration = .milliseconds(12), history: any SQLHistoryStore = InMemorySQLHistoryStore()
    ) -> SQLConsoleViewModel {
        SQLConsoleViewModel(
            client: client, connectionID: connectionID, history: history, text: text, clock: StepClock(step: step), now: { ranAt }
        )
    }

    @Test func enginesWithoutSQLAreUnsupported() async {
        let model = console(MockDatabaseClient(), text: "SELECT 1")
        #expect(!model.isSupported)
        #expect(!model.canRun)
        await model.runAll()
        #expect(model.history.isEmpty)
    }

    @Test func blankOrCommentOnlyTextCantRun() async {
        let client = MockSQLClient()
        let model = console(client, text: "  \n -- just a note\n ")
        #expect(model.statements.isEmpty)
        #expect(!model.canRun)
        await model.runAll()
        #expect(await client.ranSQL.isEmpty)
        #expect(model.lastBatch == nil)
    }

    @Test func runAllRunsEveryLineAndStatementInOrder() async {
        let client = MockSQLClient()
        let model = console(client, text: "SELECT 1;\nSELECT 2; SELECT 3\n\nSELECT 4")
        await model.runAll()
        #expect(await client.ranSQL == ["SELECT 1", "SELECT 2", "SELECT 3", "SELECT 4"])
        #expect(model.lastBatch?.entries.count == 4)
        #expect(model.lastBatch?.succeeded == true)
        #expect(model.lastBatch?.duration == .milliseconds(48))
        #expect(!model.isRunning)
    }

    @Test func eachDistinctStatementGetsItsOwnResult() async {
        let model = console(MockSQLClient(), text: "SELECT 1\nSELECT  2")
        await model.runAll()
        #expect(model.resultOrder == ["SELECT 1", "SELECT 2"])
        #expect(model.result(for: "SELECT 2")?.sql == "SELECT  2")
        #expect(model.result(for: "SELECT 1")?.state.value?.rows.count == 1)
        #expect(model.result(for: "SELECT 1")?.summary == SQLRunSummary(succeeded: true, duration: .milliseconds(12), rowCount: 1, errorMessage: nil))
    }

    @Test func rerunningTheSameQueryReusesItsResult() async {
        let model = console(MockSQLClient(), text: "SELECT 1")
        await model.runAll()
        model.text = "select 9\nSELECT   1  "
        await model.run([model.statements[1]].map(\.sql))
        #expect(model.resultOrder == ["SELECT 1"])
        #expect(model.focusRequest?.resultID == "SELECT 1")
    }

    @Test func aRunStopsAtTheFirstFailure() async {
        let client = MockSQLClient(failing: ["DELETE FROM t"])
        let model = console(client, text: "SELECT 1\nDELETE FROM t\nSELECT 3")
        await model.runAll()
        #expect(await client.ranSQL == ["SELECT 1", "DELETE FROM t"])
        let batch = model.lastBatch
        #expect(batch?.succeeded == false)
        #expect(batch?.skippedCount == 1)
        #expect(batch?.entries.last?.summary.errorMessage == "failed: DELETE FROM t")
        #expect(model.focusRequest?.resultID == "DELETE FROM t")
        guard case .failed = model.result(for: "DELETE FROM t")?.state else {
            Issue.record("Expected failed state")
            return
        }
    }

    @Test func oneStatementRunsOnItsOwn() async throws {
        let client = MockSQLClient()
        let model = console(client, text: "SELECT 1\nSELECT 2")
        await model.run(try #require(model.statements.last))
        #expect(await client.ranSQL == ["SELECT 2"])
        #expect(model.lastBatch?.requestedCount == 1)
    }

    @Test func showsRunningAndIgnoresAnotherRunMeanwhile() async {
        let gate = Gate()
        let client = MockSQLClient(gate: gate)
        let model = console(client, text: "SELECT 1")
        let run = Task { await model.runAll() }
        await gate.waitUntilEntered()
        #expect(model.isRunning)
        #expect(!model.canRun)
        #expect(model.result(for: "SELECT 1")?.state.isLoading == true)
        await model.runAll()
        await gate.open()
        await run.value
        #expect(await client.ranSQL.count == 1)
        #expect(!model.isRunning)
    }

    @Test func focusAndDiscardResults() async {
        let model = console(MockSQLClient(), text: "SELECT 1\nSELECT 2")
        await model.runAll()
        model.focus("SELECT 1")
        #expect(model.focusRequest?.resultID == "SELECT 1")
        let serial = model.focusRequest?.serial
        model.focus("SELECT 1")
        #expect(model.focusRequest?.serial != serial)
        model.discardResult("SELECT 1")
        #expect(model.result(for: "SELECT 1") == nil)
        #expect(model.resultOrder == ["SELECT 2"])
        model.focus("SELECT 1")
        #expect(model.focusRequest?.resultID == "SELECT 1")
        #expect(model.focusRequest?.serial == serial.map { $0 + 1 })
    }

    @Test func theServersErrorIsKept() async {
        let model = console(SQLErrorClient(message: #"syntax error at or near "FORM""#), text: "SELECT * FORM customers")
        await model.runAll()
        #expect(model.lastBatch?.entries.first?.summary.errorMessage == #"syntax error at or near "FORM""#)
    }

    // MARK: - History

    @Test func everyStatementIsRecordedNewestFirst() async {
        let model = console(MockSQLClient(), text: "SELECT 1; SELECT 2")
        await model.runAll()
        #expect(model.history.map(\.sql) == ["SELECT 2", "SELECT 1"])
        #expect(model.history.first?.ranAt == ranAt)
        #expect(model.history.first?.summary == SQLRunSummary(succeeded: true, duration: .milliseconds(12), rowCount: 1, errorMessage: nil))
    }

    @Test func failedStatementsAreRecordedWithTheirError() async {
        let model = console(SQLErrorClient(message: "permission denied for table customers"), text: "DELETE FROM customers")
        await model.runAll()
        #expect(model.history.first?.summary.succeeded == false)
        #expect(model.history.first?.summary.errorMessage == "permission denied for table customers")
    }

    @Test func aHistoryItemRunsAsWrittenWithoutTouchingTheEditor() async throws {
        let client = MockSQLClient()
        let model = console(client, text: "SELECT 1")
        await model.runAll()
        model.text = "SELECT 2"
        await model.run(try #require(model.history.first))
        #expect(await client.ranSQL == ["SELECT 1", "SELECT 1"])
        #expect(model.text == "SELECT 2")
        #expect(model.history.count == 2)
    }

    @Test func historyIsPerConnectionAndSurvivesReopening() async {
        let store = InMemorySQLHistoryStore()
        await console(MockSQLClient(), text: "SELECT 1", history: store).runAll()
        #expect(console(MockSQLClient(), text: "", history: store).history.map(\.sql) == ["SELECT 1"])
        #expect(SQLConsoleViewModel(client: MockSQLClient(), connectionID: UUID(), history: store).history.isEmpty)
    }

    @Test func editDeleteAndClear() async {
        let model = console(MockSQLClient(), text: "SELECT 1\nSELECT 2")
        await model.runAll()
        let oldest = model.history[1]
        model.edit(oldest)
        #expect(model.text == "SELECT 1")
        model.deleteHistory(oldest)
        #expect(model.history.map(\.sql) == ["SELECT 2"])
        model.clearHistory()
        #expect(model.history.isEmpty)
    }

    // MARK: - SQL files

    @Test func importingFillsAnEmptyEditorOrAppends() {
        let model = console(MockSQLClient(), text: "  ")
        model.importSQL("SELECT 1;")
        #expect(model.text == "SELECT 1;")
        model.importSQL("SELECT 2;")
        #expect(model.text == "SELECT 1;\nSELECT 2;")
        #expect(model.statements.map(\.sql) == ["SELECT 1", "SELECT 2"])
    }

    @Test func anUnreadableFileIsReported() {
        let model = console(MockSQLClient(), text: "SELECT 1")
        model.importSQL(from: URL(filePath: "/nonexistent/\(UUID().uuidString).sql"))
        #expect(model.didFailToImport)
        #expect(model.text == "SELECT 1")
        model.importSQL("SELECT 2")
        #expect(!model.didFailToImport)
    }

    @Test func historyCanBeTurnedOff() async {
        let store = InMemorySQLHistoryStore()
        await console(MockSQLClient(), text: "SELECT 1", history: store).runAll()
        let model = SQLConsoleViewModel(
            client: MockSQLClient(), connectionID: connectionID, history: store, text: "SELECT 2", recordsHistory: false
        )
        #expect(model.history.isEmpty)
        await model.runAll()
        #expect(model.history.isEmpty)
        #expect(store.items(for: connectionID).map(\.sql) == ["SELECT 1"])
        #expect(model.lastBatch?.entries.count == 1)
    }
}

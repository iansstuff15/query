import Foundation
import Observation
import os

/// The workspace's SQL console. The editor's text splits into statements (each line, and each
/// `;`), which run one at a time or all together. Every distinct statement keeps its latest
/// result for its own tab in the center panel; the console shows how the last run went, and
/// this connection's history of statements (each can run again).
@MainActor
@Observable
final class SQLConsoleViewModel {
    var text: String
    /// Latest result per distinct statement, keyed by `SQLEditorStatement.key(for:)`.
    private(set) var results: [String: SQLQueryResult] = [:]
    /// Result keys in the order their tabs were first opened.
    private(set) var resultOrder: [String] = []
    private(set) var isRunning = false
    /// How the last run went.
    private(set) var lastBatch: SQLBatchSummary?
    /// The result tab the workspace should show; set as each statement starts.
    private(set) var focusRequest: SQLFocusRequest?
    /// This connection's past statements, newest first.
    private(set) var history: [SQLHistoryItem] = []
    /// The last file import failed (too large, or not readable as text).
    private(set) var didFailToImport = false

    private let runner: (any SQLConsoleRunning)?
    private let connectionID: UUID
    private let historyStore: any SQLHistoryStore
    /// `ENABLE_SQL_HISTORY`; off records nothing.
    private let recordsHistory: Bool
    private let now: () -> Date
    /// Starts timing; the returned closure reports the time elapsed since.
    private let startTimer: () -> () -> Duration
    private var focusSerial = 0

    convenience init(
        client: any DatabaseClient, connectionID: UUID = UUID(), history: any SQLHistoryStore = InMemorySQLHistoryStore(), text: String = "",
        recordsHistory: Bool = true
    ) {
        self.init(
            client: client, connectionID: connectionID, history: history, text: text, clock: ContinuousClock(), now: Date.init,
            recordsHistory: recordsHistory
        )
    }

    init<C: Clock<Duration>>(
        client: any DatabaseClient, connectionID: UUID, history: any SQLHistoryStore, text: String = "", clock: C,
        now: @escaping () -> Date, recordsHistory: Bool = true
    ) {
        runner = client as? any SQLConsoleRunning
        self.connectionID = connectionID
        historyStore = history
        self.recordsHistory = recordsHistory
        self.text = text
        self.now = now
        startTimer = {
            let start = clock.now
            return { start.duration(to: clock.now) }
        }
        self.history = recordsHistory ? history.items(for: connectionID) : []
    }

    /// Engines without SQL (MongoDB, Redis, …) show a fallback instead of the editor.
    var isSupported: Bool { runner != nil }

    /// The editor's statements, in order.
    var statements: [SQLEditorStatement] { SQLStatementSplitter.statements(in: text) }

    var canRun: Bool {
        isSupported && !isRunning && !statements.isEmpty
    }

    func result(for id: String) -> SQLQueryResult? {
        results[id]
    }

    /// Runs every statement in the editor, in order, stopping at the first failure.
    func runAll() async {
        await run(statements.map(\.sql))
    }

    /// Runs one statement from the editor (its ▶ button).
    func run(_ statement: SQLEditorStatement) async {
        await run([statement.sql])
    }

    /// Runs a past statement again, as written (the editor is left alone).
    func run(_ item: SQLHistoryItem) async {
        await run([item.sql])
    }

    /// Runs `sqls` in order, stopping at the first failure. Each gets (or reuses) its result tab.
    func run(_ sqls: [String]) async {
        let sqls = sqls.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let runner, !isRunning, !sqls.isEmpty else { return }
        isRunning = true
        defer { isRunning = false }
        var entries: [SQLBatchSummary.Entry] = []
        for sql in sqls {
            let summary = await execute(sql, with: runner)
            entries.append(SQLBatchSummary.Entry(id: UUID(), resultID: SQLEditorStatement.key(for: sql), sql: sql, summary: summary))
            lastBatch = SQLBatchSummary(entries: entries, requestedCount: sqls.count)
            if !summary.succeeded { break }
        }
    }

    /// Shows a statement's result tab again (from the run summary).
    func focus(_ resultID: String) {
        guard results[resultID] != nil else { return }
        requestFocus(resultID)
    }

    /// Forgets a result whose tab was closed.
    func discardResult(_ id: String) {
        results[id] = nil
        resultOrder.removeAll { $0 == id }
    }

    /// Adds a `.sql` file's contents to the editor: replaces it when empty, otherwise appends on
    /// a new line so nothing typed is lost.
    func importSQL(from url: URL) {
        do {
            importSQL(try SQLFileReader.read(url))
        } catch {
            AppLog.database.error("Opening a SQL file failed: \(String(describing: error), privacy: .private)")
            didFailToImport = true
        }
    }

    func importSQL(_ contents: String) {
        didFailToImport = false
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = contents
        } else {
            text += (text.hasSuffix("\n") ? "" : "\n") + contents
        }
    }

    /// Puts a past statement in the editor.
    func edit(_ item: SQLHistoryItem) {
        text = item.sql
    }

    func deleteHistory(_ item: SQLHistoryItem) {
        historyStore.delete(item.id)
        history = historyStore.items(for: connectionID)
    }

    func clearHistory() {
        historyStore.clear(for: connectionID)
        history = []
    }

    private func execute(_ sql: String, with runner: any SQLConsoleRunning) async -> SQLRunSummary {
        let id = SQLEditorStatement.key(for: sql)
        let ranAt = now()
        if results[id] == nil { resultOrder.append(id) }
        results[id] = SQLQueryResult(id: id, sql: sql, state: .loading, summary: nil)
        requestFocus(id)

        let elapsed = startTimer()
        let outcome: Result<QueryResult, any Error>
        do { outcome = .success(try await runner.runSQL(sql)) } catch { outcome = .failure(error) }
        let duration = elapsed()

        let summary: SQLRunSummary
        switch outcome {
        case .success(let rows):
            summary = SQLRunSummary(succeeded: true, duration: duration, rowCount: rows.rows.count, errorMessage: nil)
            results[id]?.state = .loaded(rows)
        case .failure(let error):
            AppLog.database.error("SQL console statement failed: \(String(describing: error), privacy: .private)")
            let message = if case DatabaseError.statementFailed(let message) = error { message } else { String?.none }
            summary = SQLRunSummary(succeeded: false, duration: duration, rowCount: nil, errorMessage: message)
            results[id]?.state = .failed(error)
        }
        results[id]?.summary = summary
        if recordsHistory {
            historyStore.record(SQLHistoryItem(id: UUID(), sql: sql, ranAt: ranAt, summary: summary), for: connectionID)
            history = historyStore.items(for: connectionID)
        }
        return summary
    }

    private func requestFocus(_ id: String) {
        focusSerial += 1
        focusRequest = SQLFocusRequest(resultID: id, serial: focusSerial)
    }
}

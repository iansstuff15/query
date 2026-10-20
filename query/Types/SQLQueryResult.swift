import Foundation

/// The latest run of one distinct statement; each has its own result tab.
nonisolated struct SQLQueryResult: Identifiable, Sendable {
    /// `SQLEditorStatement.key(for:)` of the statement.
    let id: String
    let sql: String
    var state: LoadState<QueryResult>
    var summary: SQLRunSummary?
}

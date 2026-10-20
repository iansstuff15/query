import Foundation

/// How the last Run went: each statement that ran, in order, and how many were asked for.
/// A run stops at the first failure, so later statements don't run.
nonisolated struct SQLBatchSummary: Equatable, Sendable {
    struct Entry: Equatable, Identifiable, Sendable {
        let id: UUID
        /// The statement's result tab.
        let resultID: String
        let sql: String
        let summary: SQLRunSummary
    }

    let entries: [Entry]
    let requestedCount: Int

    var succeeded: Bool { entries.count == requestedCount && entries.allSatisfy(\.summary.succeeded) }
    var duration: Duration { entries.reduce(.zero) { $0 + $1.summary.duration } }
    /// Statements skipped because an earlier one failed.
    var skippedCount: Int { requestedCount - entries.count }
}

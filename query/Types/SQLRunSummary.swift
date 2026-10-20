import Foundation

/// What the SQL console shows about its last run.
nonisolated struct SQLRunSummary: Equatable, Sendable {
    let succeeded: Bool
    let duration: Duration
    /// Rows returned, when the statement succeeded.
    let rowCount: Int?
    /// The server's error, when it sent one.
    let errorMessage: String?
}

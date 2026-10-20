import Foundation

/// A past SQL console run: what ran, when, and how it went.
nonisolated struct SQLHistoryItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let sql: String
    let ranAt: Date
    let summary: SQLRunSummary
}

import Foundation
import SwiftData

/// One SQL console run, kept per saved connection so it can be run again from the History tab.
@Model
final class SQLHistoryEntry {
    @Attribute(.unique) var id: UUID
    var connectionID: UUID
    var sql: String
    var ranAt: Date
    var succeeded: Bool
    var durationMilliseconds: Int
    var rowCount: Int?
    var errorMessage: String?

    init(item: SQLHistoryItem, connectionID: UUID) {
        id = item.id
        self.connectionID = connectionID
        sql = item.sql
        ranAt = item.ranAt
        succeeded = item.summary.succeeded
        durationMilliseconds = Int(item.summary.duration / .milliseconds(1))
        rowCount = item.summary.rowCount
        errorMessage = item.summary.errorMessage
    }

    var item: SQLHistoryItem {
        SQLHistoryItem(
            id: id, sql: sql, ranAt: ranAt,
            summary: SQLRunSummary(
                succeeded: succeeded, duration: .milliseconds(durationMilliseconds), rowCount: rowCount, errorMessage: errorMessage
            )
        )
    }
}

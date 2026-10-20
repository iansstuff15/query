import Foundation
import SwiftData

enum SQLHistoryQueries {
    /// A connection's runs, newest first.
    static func forConnection(_ connectionID: UUID) -> FetchDescriptor<SQLHistoryEntry> {
        FetchDescriptor<SQLHistoryEntry>(
            predicate: #Predicate { $0.connectionID == connectionID },
            sortBy: [SortDescriptor(\.ranAt, order: .reverse)]
        )
    }

    static func byID(_ id: UUID) -> FetchDescriptor<SQLHistoryEntry> {
        FetchDescriptor<SQLHistoryEntry>(predicate: #Predicate { $0.id == id })
    }
}

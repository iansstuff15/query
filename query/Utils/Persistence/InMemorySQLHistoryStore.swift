import Foundation

/// SQL history that lasts only as long as the window, for previews and tests.
@MainActor
final class InMemorySQLHistoryStore: SQLHistoryStore {
    private var entries: [UUID: [SQLHistoryItem]] = [:]
    private let limit: Int

    /// Nonisolated so it can serve as a default argument.
    nonisolated init(items: [SQLHistoryItem] = [], for connectionID: UUID? = nil, limit: Int = AppConfig.sqlHistoryLimit) {
        self.limit = limit
        if let connectionID { entries[connectionID] = items }
    }

    func items(for connectionID: UUID) -> [SQLHistoryItem] {
        entries[connectionID] ?? []
    }

    func record(_ item: SQLHistoryItem, for connectionID: UUID) {
        entries[connectionID] = Array(([item] + items(for: connectionID)).prefix(limit))
    }

    func delete(_ id: UUID) {
        for key in entries.keys { entries[key]?.removeAll { $0.id == id } }
    }

    func clear(for connectionID: UUID) {
        entries[connectionID] = nil
    }
}

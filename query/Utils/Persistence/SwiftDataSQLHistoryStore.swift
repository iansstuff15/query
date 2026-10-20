import Foundation
import SwiftData
import os

/// SQL console history in the app's SwiftData store.
@MainActor
final class SwiftDataSQLHistoryStore: SQLHistoryStore {
    private let context: ModelContext
    private let limit: Int

    init(context: ModelContext, limit: Int = AppConfig.sqlHistoryLimit) {
        self.context = context
        self.limit = limit
    }

    func items(for connectionID: UUID) -> [SQLHistoryItem] {
        do {
            return try context.fetch(SQLHistoryQueries.forConnection(connectionID)).map(\.item)
        } catch {
            AppLog.database.error("Reading SQL history failed: \(String(describing: error), privacy: .private)")
            return []
        }
    }

    func record(_ item: SQLHistoryItem, for connectionID: UUID) {
        context.insert(SQLHistoryEntry(item: item, connectionID: connectionID))
        do {
            let entries = try context.fetch(SQLHistoryQueries.forConnection(connectionID))
            for stale in entries.dropFirst(limit) { context.delete(stale) }
            try context.save()
        } catch {
            AppLog.database.error("Saving SQL history failed: \(String(describing: error), privacy: .private)")
        }
    }

    func delete(_ id: UUID) {
        do {
            for entry in try context.fetch(SQLHistoryQueries.byID(id)) { context.delete(entry) }
            try context.save()
        } catch {
            AppLog.database.error("Deleting SQL history failed: \(String(describing: error), privacy: .private)")
        }
    }

    func clear(for connectionID: UUID) {
        do {
            for entry in try context.fetch(SQLHistoryQueries.forConnection(connectionID)) { context.delete(entry) }
            try context.save()
        } catch {
            AppLog.database.error("Clearing SQL history failed: \(String(describing: error), privacy: .private)")
        }
    }
}

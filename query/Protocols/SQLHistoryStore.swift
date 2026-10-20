import Foundation

/// Per-connection SQL console history, newest first.
@MainActor
protocol SQLHistoryStore: AnyObject {
    func items(for connectionID: UUID) -> [SQLHistoryItem]
    /// Adds a run, keeping at most `AppConfig.sqlHistoryLimit` per connection.
    func record(_ item: SQLHistoryItem, for connectionID: UUID)
    func delete(_ id: UUID)
    func clear(for connectionID: UUID)
}

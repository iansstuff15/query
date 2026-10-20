import Foundation
import SwiftData
import Testing
@testable import query

@MainActor
@Suite("SwiftDataSQLHistoryStore", .tags(.integration))
struct SwiftDataSQLHistoryStoreTests {
    private let container: ModelContainer
    private let connection = UUID()

    init() throws {
        container = try ModelContainer(
            for: SavedConnection.self, SQLHistoryEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func item(_ sql: String, minute: Double, succeeded: Bool = true) -> SQLHistoryItem {
        SQLHistoryItem(
            id: UUID(), sql: sql, ranAt: Date(timeIntervalSince1970: 1_768_035_600 + minute * 60),
            summary: SQLRunSummary(
                succeeded: succeeded, duration: .milliseconds(15), rowCount: succeeded ? 3 : nil, errorMessage: succeeded ? nil : "denied"
            )
        )
    }

    @Test func roundTripsNewestFirstPerConnection() {
        let store = SwiftDataSQLHistoryStore(context: container.mainContext)
        store.record(item("SELECT 1", minute: 0), for: connection)
        store.record(item("DELETE FROM t", minute: 1, succeeded: false), for: connection)
        store.record(item("SELECT other", minute: 2), for: UUID())
        let items = store.items(for: connection)
        #expect(items.map(\.sql) == ["DELETE FROM t", "SELECT 1"])
        #expect(items.first?.summary == SQLRunSummary(succeeded: false, duration: .milliseconds(15), rowCount: nil, errorMessage: "denied"))
    }

    @Test func keepsOnlyTheNewestRunsUpToTheLimit() {
        let store = SwiftDataSQLHistoryStore(context: container.mainContext, limit: 2)
        for minute in 0..<4 { store.record(item("SELECT \(minute)", minute: Double(minute)), for: connection) }
        #expect(store.items(for: connection).map(\.sql) == ["SELECT 3", "SELECT 2"])
    }

    @Test func deletesOneOrClearsAConnection() {
        let store = SwiftDataSQLHistoryStore(context: container.mainContext)
        let first = item("SELECT 1", minute: 0)
        store.record(first, for: connection)
        store.record(item("SELECT 2", minute: 1), for: connection)
        let other = UUID()
        store.record(item("SELECT 3", minute: 2), for: other)
        store.delete(first.id)
        #expect(store.items(for: connection).map(\.sql) == ["SELECT 2"])
        store.clear(for: connection)
        #expect(store.items(for: connection).isEmpty)
        #expect(store.items(for: other).count == 1)
    }
}

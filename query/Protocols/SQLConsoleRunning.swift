import Foundation

/// A client that can run SQL typed into the SQL console.
nonisolated protocol SQLConsoleRunning: DatabaseClient {
    /// Runs one statement as written and returns its rows (empty for statements that return none).
    func runSQL(_ sql: String) async throws -> QueryResult
}

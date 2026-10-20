import Foundation

/// A connection to a database server. Implementations own the wire protocol.
nonisolated protocol DatabaseClient: Sendable {
    func listObjects() async throws -> [DatabaseObject]
    func columns(of object: DatabaseObject) async throws -> [ColumnInfo]
    func rows(
        of object: DatabaseObject,
        columns: [ColumnInfo],
        rules: [FilterRule],
        limit: Int
    ) async throws -> QueryResult
    /// Releases sockets / handles. Safe to call more than once.
    func close() async
    /// The native query (SQL, filter document, DSL…) `rows` would send, for display.
    nonisolated func queryPreview(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) -> String?
}

nonisolated extension DatabaseClient {
    func close() async {}

    func queryPreview(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) -> String? {
        nil
    }
}

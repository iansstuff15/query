import Foundation

/// A client that can save edits to a table row (the Row tab).
nonisolated protocol RowUpdating: DatabaseClient {
    /// False for read-only connections (SQLite and DuckDB files are opened read-only) and
    /// engines without a plain `UPDATE`.
    var canUpdateRows: Bool { get }
    /// The table's primary-key columns, in key order; empty when it has none or it's unknown.
    func primaryKey(of object: DatabaseObject) async throws -> [String]
    /// The columns the current user can change in this table: not generated, not an
    /// always-generated identity, updatable, and granted UPDATE. `nil` when the engine can't say,
    /// in which case every column is treated as editable.
    func editableColumns(of object: DatabaseObject) async throws -> Set<String>?
    /// Saves `change`. Throws `DatabaseError.statementFailed` with the server's message when
    /// the server rejects it (for example, a read-only user).
    func update(_ change: RowChange) async throws
}

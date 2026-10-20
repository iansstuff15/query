import Foundation
import SQLite3
import os

/// SQLite through the system `libsqlite3`, opened read-only. The file comes from an open
/// panel (security-scoped) or a path inside the sandbox container.
actor SQLiteDatabaseClient: SQLExecuting {
    private let fileURL: URL
    private var handle: OpaquePointer?
    private var isAccessingScope = false

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The file is opened read-only, so rows can't be edited.
    nonisolated var canUpdateRows: Bool { false }
    nonisolated var dialect: any SQLDialect { SQLiteDialect() }
    nonisolated func objectsStatement() -> SQLStatement { SQLiteCatalogQueries.objects }
    nonisolated func columnsStatement(of object: DatabaseObject) -> SQLStatement { SQLiteCatalogQueries.columns(of: object) }

    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        let database = try open()
        var prepared: OpaquePointer?
        guard sqlite3_prepare_v2(database, statement.sql, -1, &prepared, nil) == SQLITE_OK, let prepared else {
            AppLog.database.error("SQLite prepare failed: \(String(cString: sqlite3_errmsg(database)), privacy: .private)")
            throw DatabaseError.queryFailed
        }
        defer { sqlite3_finalize(prepared) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, value) in statement.bindings.enumerated() {
            sqlite3_bind_text(prepared, Int32(offset + 1), value, -1, transient)
        }
        var rows: [[String?]] = []
        let columnCount = sqlite3_column_count(prepared)
        while true {
            let step = sqlite3_step(prepared)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW else {
                AppLog.database.error("SQLite step failed: \(String(cString: sqlite3_errmsg(database)), privacy: .private)")
                throw DatabaseError.queryFailed
            }
            rows.append((0..<columnCount).map { column in
                sqlite3_column_text(prepared, column).map { String(cString: $0) }
            })
        }
        return rows
    }

    func close() async {
        if let handle {
            sqlite3_close_v2(handle)
            self.handle = nil
        }
        if isAccessingScope {
            fileURL.stopAccessingSecurityScopedResource()
            isAccessingScope = false
        }
    }

    private func open() throws -> OpaquePointer {
        if let handle { return handle }
        isAccessingScope = fileURL.startAccessingSecurityScopedResource()
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        // `immutable=1` lets read-only access work for WAL databases without a writable -shm.
        var components = URLComponents(url: fileURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "immutable", value: "1")]
        let uri = components?.string ?? fileURL.absoluteString
        guard sqlite3_open_v2(uri, &database, flags, nil) == SQLITE_OK, let database else {
            AppLog.database.error("SQLite open failed for \(self.fileURL.path, privacy: .private)")
            sqlite3_close_v2(database)
            throw DatabaseError.connectionFailed
        }
        handle = database
        return database
    }
}

import DuckDB
import Foundation
import os

/// DuckDB through the official `duckdb-swift` package, opened read-only.
actor DuckDBDatabaseClient: SQLExecuting {
    private let fileURL: URL
    private var connection: Connection?
    private var database: Database?
    private var isAccessingScope = false

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The file is opened read-only, so rows can't be edited.
    nonisolated var canUpdateRows: Bool { false }
    nonisolated var dialect: any SQLDialect { DuckDBDialect() }
    nonisolated func objectsStatement() -> SQLStatement { DuckDBCatalogQueries.objects }
    nonisolated func columnsStatement(of object: DatabaseObject) -> SQLStatement { DuckDBCatalogQueries.columns(of: object) }

    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        let connection = try open()
        do {
            let prepared = try PreparedStatement(connection: connection, query: statement.sql)
            for (offset, value) in statement.bindings.enumerated() {
                try prepared.bind(value, at: offset + 1)
            }
            let result = try prepared.execute()
            let columns = (0..<result.columnCount).map { result[$0].cast(to: String.self) }
            return (0..<result.rowCount).map { row in columns.map { $0[row] } }
        } catch {
            AppLog.database.error("DuckDB query failed: \(String(reflecting: error), privacy: .private)")
            throw DatabaseError.queryFailed
        }
    }

    func close() async {
        connection = nil
        database = nil
        if isAccessingScope {
            fileURL.stopAccessingSecurityScopedResource()
            isAccessingScope = false
        }
    }

    private func open() throws -> Connection {
        if let connection { return connection }
        isAccessingScope = fileURL.startAccessingSecurityScopedResource()
        do {
            let configuration = Database.Configuration()
            try configuration.setValue("READ_ONLY", forKey: "access_mode")
            let database = try Database(store: .file(at: fileURL), configuration: configuration)
            let connection = try database.connect()
            self.database = database
            self.connection = connection
            return connection
        } catch {
            AppLog.database.error("DuckDB open failed: \(String(reflecting: error), privacy: .private)")
            throw DatabaseError.connectionFailed
        }
    }
}

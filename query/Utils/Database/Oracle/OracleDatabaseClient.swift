import Foundation
import Logging
import OracleNIO
import os

/// Oracle Net (TNS) protocol via the pure-Swift oracle-nio driver.
actor OracleDatabaseClient: SQLExecuting {
    private let endpoint: ServerEndpoint
    private let wireLogger = Logging.Logger(label: "by-ian.query.oracle")
    private var connection: OracleConnection?
    private var nextID = 0

    init(endpoint: ServerEndpoint) {
        self.endpoint = endpoint
    }

    /// oracle-nio asserts connections are closed before they deinitialize.
    deinit {
        if let connection {
            Task { try? await connection.close() }
        }
    }

    nonisolated var dialect: any SQLDialect { OracleDialect() }
    nonisolated func objectsStatement() -> SQLStatement { OracleCatalogQueries.objects }
    nonisolated func columnsStatement(of object: DatabaseObject) -> SQLStatement { OracleCatalogQueries.columns(of: object) }

    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        let connection = try await activeConnection()
        var binds = OracleBindings(capacity: statement.bindings.count)
        for value in statement.bindings {
            binds.append(value)
        }
        do {
            let rows = try await connection.execute(OracleStatement(unsafeSQL: statement.sql, binds: binds), logger: wireLogger)
            var values: [[String?]] = []
            for try await row in rows {
                // Iterate with the row's own iterator: oracle-nio 1.0.0-rc.4's `Collection`
                // conformance reports `startIndex == endIndex`, so `row.map` traps.
                var cells: [String?] = []
                var iterator = row.makeIterator()
                while let cell = iterator.next() {
                    cells.append(cell.bytes == nil ? nil : try cell.decode(String.self))
                }
                values.append(cells)
            }
            return values
        } catch {
            AppLog.database.error("Oracle query failed: \(String(reflecting: error), privacy: .private)")
            if connection.isClosed { self.connection = nil }
            throw DatabaseError.queryFailed
        }
    }

    func close() async {
        if let connection {
            self.connection = nil
            try? await connection.close()
        }
    }

    private func activeConnection() async throws -> OracleConnection {
        if let connection, !connection.isClosed { return connection }
        nextID += 1
        let configuration = OracleConnection.Configuration(
            host: endpoint.host,
            port: endpoint.port,
            service: .serviceName(endpoint.database ?? "FREEPDB1"),
            username: endpoint.username ?? "",
            password: endpoint.password ?? ""
        )
        do {
            let opened = try await OracleConnection.connect(configuration: configuration, id: nextID, logger: wireLogger)
            connection = opened
            return opened
        } catch {
            AppLog.database.error("Oracle connection failed: \(String(reflecting: error), privacy: .private)")
            throw DatabaseError.connectionFailed
        }
    }
}

import Foundation
import os

/// Vertica over the PostgreSQL simple-query protocol, with bindings inlined as escaped
/// literals (`SQLLiteralBinder`). Catalog SQL comes from `v_catalog`.
actor VerticaDatabaseClient: SQLExecuting {
    private let endpoint: ServerEndpoint
    private var connection: PGSimpleQueryConnection?

    init(endpoint: ServerEndpoint) {
        self.endpoint = endpoint
    }

    nonisolated var dialect: any SQLDialect { PostgresDialect.vertica }
    nonisolated func objectsStatement() -> SQLStatement { PostgresCatalogQueries.objects(.vertica) }
    nonisolated func columnsStatement(of object: DatabaseObject) -> SQLStatement { PostgresCatalogQueries.columns(of: object, flavor: .vertica) }

    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        let sql = try SQLLiteralBinder.bind(statement)
        let connection = try await activeConnection()
        do {
            return try await connection.query(sql)
        } catch DatabaseError.queryFailed {
            throw DatabaseError.queryFailed
        } catch {
            AppLog.database.error("Vertica I/O failed: \(String(reflecting: error), privacy: .private)")
            self.connection = nil
            throw DatabaseError.queryFailed
        }
    }

    func close() async {
        await connection?.close()
        connection = nil
    }

    private func activeConnection() async throws -> PGSimpleQueryConnection {
        if let connection { return connection }
        guard endpoint.tlsMode != .require else {
            AppLog.database.error("Vertica TLS is not supported yet")
            throw DatabaseError.unsupported
        }
        do {
            let opened = try await PGSimpleQueryConnection.connect(endpoint: endpoint)
            connection = opened
            return opened
        } catch {
            AppLog.database.error("Vertica connection failed: \(String(reflecting: error), privacy: .private)")
            throw DatabaseError.connectionFailed
        }
    }
}

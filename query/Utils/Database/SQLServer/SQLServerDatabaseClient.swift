import Foundation
import os

/// Microsoft SQL Server / Azure SQL over TDS (see `TDSConnection`).
actor SQLServerDatabaseClient: SQLExecuting {
    private let endpoint: ServerEndpoint
    private var connection: TDSConnection?

    init(endpoint: ServerEndpoint) {
        self.endpoint = endpoint
    }

    nonisolated var dialect: any SQLDialect { SQLServerDialect() }
    nonisolated func objectsStatement() -> SQLStatement { SQLServerCatalogQueries.objects }
    nonisolated func columnsStatement(of object: DatabaseObject) -> SQLStatement { SQLServerCatalogQueries.columns(of: object) }

    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        let connection = try await activeConnection()
        do {
            return try await connection.execute(statement)
        } catch DatabaseError.queryFailed {
            throw DatabaseError.queryFailed
        } catch {
            AppLog.database.error("SQL Server I/O failed: \(String(reflecting: error), privacy: .private)")
            self.connection = nil
            throw DatabaseError.queryFailed
        }
    }

    func close() async {
        await connection?.close()
        connection = nil
    }

    private func activeConnection() async throws -> TDSConnection {
        if let connection { return connection }
        do {
            let opened: TDSConnection
            switch endpoint.tlsMode {
            case .disable:
                opened = try await TDSConnection.connect(endpoint: endpoint, verifyCertificate: false, useTLS: false)
            case .require:
                opened = try await TDSConnection.connect(endpoint: endpoint, verifyCertificate: true, useTLS: true)
            case .prefer:
                do {
                    opened = try await TDSConnection.connect(endpoint: endpoint, verifyCertificate: false, useTLS: true)
                } catch {
                    opened = try await TDSConnection.connect(endpoint: endpoint, verifyCertificate: false, useTLS: false)
                }
            }
            connection = opened
            return opened
        } catch {
            AppLog.database.error("SQL Server connection failed: \(String(reflecting: error), privacy: .private)")
            throw DatabaseError.connectionFailed
        }
    }
}

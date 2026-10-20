import Foundation
import Logging
import MySQLNIO
import NIOPosix
import os

/// MySQL / MariaDB client/server protocol via MySQLNIO. TLS is used when the server offers it.
actor MySQLDatabaseClient: SQLExecuting {
    private let endpoint: ServerEndpoint
    private let wireLogger = Logging.Logger(label: "by-ian.query.mysql")
    private var connection: MySQLConnection?

    init(endpoint: ServerEndpoint) {
        self.endpoint = endpoint
    }

    /// MySQLNIO asserts connections are closed before they deinitialize.
    deinit {
        connection?.close().whenComplete { _ in }
    }

    nonisolated var dialect: any SQLDialect { MySQLDialect() }
    nonisolated func objectsStatement() -> SQLStatement { MySQLCatalogQueries.objects }
    nonisolated func columnsStatement(of object: DatabaseObject) -> SQLStatement { MySQLCatalogQueries.columns(of: object) }
    nonisolated func primaryKeyStatement(of object: DatabaseObject) -> SQLStatement? { MySQLCatalogQueries.primaryKey(of: object) }
    nonisolated func editableColumnsStatement(of object: DatabaseObject) -> SQLStatement? { MySQLCatalogQueries.editableColumns(of: object) }
    nonisolated func userManagementSQL() -> (any UserManagementSQL)? { MySQLUserSQL() }

    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        let connection = try await activeConnection()
        do {
            let rows = try await connection.query(statement.sql, statement.bindings.map(MySQLData.init(string:))).get()
            return rows.map(Self.text)
        } catch {
            AppLog.database.error("MySQL query failed: \(String(reflecting: error), privacy: .private)")
            if connection.isClosed { self.connection = nil }
            throw Self.serverMessage(error).map(DatabaseError.statementFailed) ?? DatabaseError.queryFailed
        }
    }

    /// Runs console SQL with column names. Statements that return no rows give an empty result.
    func runSQL(_ sql: String) async throws -> QueryResult {
        let connection = try await activeConnection()
        do {
            let rows = try await connection.query(sql).get()
            let names = rows.first?.columnDefinitions.map(\.name) ?? []
            return QueryResult(columnNames: names, values: rows.map(Self.text))
        } catch {
            AppLog.database.error("MySQL console query failed: \(String(reflecting: error), privacy: .private)")
            if connection.isClosed { self.connection = nil }
            throw Self.serverMessage(error).map(DatabaseError.statementFailed) ?? DatabaseError.queryFailed
        }
    }

    private static func serverMessage(_ error: any Error) -> String? {
        switch error as? MySQLError {
        case .server(let packet): packet.errorMessage
        case .duplicateEntry(let message), .invalidSyntax(let message): message
        default: nil
        }
    }

    private static func text(_ row: MySQLRow) -> [String?] {
        zip(row.columnDefinitions, row.values).map { definition, buffer -> String? in
            guard let buffer else { return nil }
            return MySQLCellText.text(MySQLData(type: definition.columnType, format: row.format, buffer: buffer,
                                                isUnsigned: definition.flags.contains(.COLUMN_UNSIGNED)))
        }
    }

    func close() async {
        if let connection {
            self.connection = nil
            try? await connection.close().get()
        }
    }

    private func activeConnection() async throws -> MySQLConnection {
        if let connection, !connection.isClosed { return connection }
        do {
            let address = try SocketAddress.makeAddressResolvingHost(endpoint.host, port: endpoint.port)
            var tls: TLSConfiguration?
            switch endpoint.tlsMode {
            case .disable:
                tls = nil
            case .prefer:
                var configuration = TLSConfiguration.makeClientConfiguration()
                configuration.certificateVerification = .none
                tls = configuration
            case .require:
                tls = .makeClientConfiguration()
            }
            let opened = try await MySQLConnection.connect(
                to: address,
                username: endpoint.username ?? "root",
                database: endpoint.database ?? "",
                password: endpoint.password,
                tlsConfiguration: tls,
                serverHostname: endpoint.host,
                logger: wireLogger,
                on: MultiThreadedEventLoopGroup.singleton.any()
            ).get()
            connection = opened
            return opened
        } catch {
            AppLog.database.error("MySQL connection failed: \(String(reflecting: error), privacy: .private)")
            throw DatabaseError.connectionFailed
        }
    }
}

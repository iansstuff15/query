import Foundation
import Logging
import PostgresNIO
import os

/// PostgreSQL wire protocol (TCP, optional TLS) via PostgresNIO — the same approach as
/// TablePlus, which links libpq. Also serves CockroachDB, Greenplum, Redshift and Vertica.
/// One connection per window, opened lazily.
actor PostgresDatabaseClient: SQLExecuting {
    private let endpoint: ServerEndpoint
    private let flavor: PostgresFlavor
    private let wireLogger = Logging.Logger(label: "by-ian.query.postgres")
    private var connection: PostgresConnection?
    private var pending: Task<PostgresConnection, any Error>?
    private var nextConnectionID = 0

    init(endpoint: ServerEndpoint, flavor: PostgresFlavor) {
        self.endpoint = endpoint
        self.flavor = flavor
    }

    /// PostgresNIO asserts connections are closed before they deinitialize.
    deinit {
        connection?.close().whenComplete { _ in }
    }

    nonisolated var dialect: any SQLDialect { flavor.dialect }

    nonisolated func objectsStatement() -> SQLStatement { PostgresCatalogQueries.objects(flavor) }

    nonisolated func columnsStatement(of object: DatabaseObject) -> SQLStatement {
        PostgresCatalogQueries.columns(of: object, flavor: flavor)
    }

    nonisolated func primaryKeyStatement(of object: DatabaseObject) -> SQLStatement? {
        PostgresCatalogQueries.primaryKey(of: object)
    }

    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] {
        try await execute(columnsStatement(of: object)).compactMap { row in
            guard row.count >= 2, let name = row[0] else { return nil }
            return ColumnInfo(name: name, dataType: PostgresCatalogQueries.castableType(row[1] ?? ""))
        }
    }

    /// Runs a statement and returns every cell as text; queries cast result columns to text,
    /// so one decoder handles every type.
    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        let connection = try await activeConnection()
        var bindings = PostgresBindings(capacity: statement.bindings.count)
        for value in statement.bindings {
            bindings.append(value)
        }
        do {
            let rows = try await connection.query(PostgresQuery(unsafeSQL: statement.sql, binds: bindings), logger: wireLogger)
            var values: [[String?]] = []
            for try await row in rows {
                values.append(try row.map { cell in
                    cell.bytes == nil ? nil : try cell.decode(String.self)
                })
            }
            return values
        } catch {
            AppLog.database.error("Postgres query failed: \(String(reflecting: error), privacy: .private)")
            if connection.isClosed { self.connection = nil }
            throw Self.serverMessage(error).map(DatabaseError.statementFailed) ?? DatabaseError.queryFailed
        }
    }

    /// Runs console SQL with column names, decoding each cell by its type.
    func runSQL(_ sql: String) async throws -> QueryResult {
        let connection = try await activeConnection()
        do {
            let rows = try await connection.query(PostgresQuery(unsafeSQL: sql), logger: wireLogger)
            var values: [[String?]] = []
            for try await row in rows {
                values.append(row.map(PostgresCellText.text))
            }
            return QueryResult(columnNames: rows.columns.map(\.name), values: values)
        } catch {
            AppLog.database.error("Postgres console query failed: \(String(reflecting: error), privacy: .private)")
            if connection.isClosed { self.connection = nil }
            throw Self.serverMessage(error).map(DatabaseError.statementFailed) ?? DatabaseError.queryFailed
        }
    }

    /// "message", plus the server's detail and hint lines when it sends them.
    private static func serverMessage(_ error: any Error) -> String? {
        guard let info = (error as? PSQLError)?.serverInfo, let message = info[.message] else { return nil }
        return [message, info[.detail], info[.hint]].compactMap { $0 }.joined(separator: "\n")
    }

    func close() async {
        pending?.cancel()
        pending = nil
        if let connection {
            self.connection = nil
            try? await connection.close()
        }
    }

    private func activeConnection() async throws -> PostgresConnection {
        if let connection, !connection.isClosed { return connection }
        if let pending { return try await pending.value }
        nextConnectionID += 1
        let id = nextConnectionID
        let endpoint = endpoint
        let logger = wireLogger
        let task = Task { () throws -> PostgresConnection in
            try await PostgresConnection.connect(configuration: try Self.configuration(for: endpoint), id: id, logger: logger)
        }
        pending = task
        defer { pending = nil }
        do {
            let opened = try await task.value
            connection = opened
            return opened
        } catch {
            AppLog.database.error(
                "Postgres connection to \(endpoint.host, privacy: .private):\(endpoint.port) failed: \(String(reflecting: error), privacy: .private)"
            )
            throw DatabaseError.connectionFailed
        }
    }

    private static func configuration(for endpoint: ServerEndpoint) throws -> PostgresConnection.Configuration {
        let tls: PostgresConnection.Configuration.TLS
        switch endpoint.tlsMode {
        case .disable:
            tls = .disable
        case .prefer:
            var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
            tlsConfiguration.certificateVerification = .none
            tls = .prefer(try NIOSSLContext(configuration: tlsConfiguration))
        case .require:
            tls = .require(try NIOSSLContext(configuration: .makeClientConfiguration()))
        }
        return PostgresConnection.Configuration(
            host: endpoint.host,
            port: endpoint.port,
            username: endpoint.username ?? "postgres",
            password: endpoint.password,
            database: endpoint.database,
            tls: tls
        )
    }
}

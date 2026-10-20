import CassandraClient
import Foundation
import NIOPosix
import os

/// Cassandra / ScyllaDB through Apple's swift-cassandra-client (DataStax C++ driver).
/// Keyspaces map to schemas; tables and materialized views to objects.
actor CassandraDatabaseClient: DatabaseClient {
    private static let systemKeyspaces: Set<String> = [
        "system", "system_auth", "system_distributed", "system_schema", "system_traces", "system_views", "system_virtual_schema",
    ]

    private let endpoint: ServerEndpoint
    private var owner: CassandraClientOwner?

    init(endpoint: ServerEndpoint) {
        self.endpoint = endpoint
    }

    func listObjects() async throws -> [DatabaseObject] {
        let tables = try await query("SELECT keyspace_name, table_name FROM system_schema.tables")
        let views = try await query("SELECT keyspace_name, view_name FROM system_schema.views")
        let objects = tables.map { ($0, DatabaseObjectKind.table) } + views.map { ($0, DatabaseObjectKind.materializedView) }
        return objects.compactMap { row, kind in
            guard row.count == 2, let keyspace = row[0], let name = row[1], !Self.systemKeyspaces.contains(keyspace) else { return nil }
            if let only = endpoint.database, !only.isEmpty, keyspace != only { return nil }
            return DatabaseObject(schema: keyspace, name: name, kind: kind)
        }
        .sorted { $0.id < $1.id }
    }

    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] {
        let rows = try await query(
            "SELECT column_name, type, kind, position FROM system_schema.columns WHERE keyspace_name = ? AND table_name = ?",
            [.string(object.schema), .string(object.name)],
            textColumns: 4
        )
        let rank = ["partition_key": 0, "clustering": 1, "static": 2, "regular": 3]
        return rows.sorted { lhs, rhs in
            let left = (rank[lhs[2] ?? ""] ?? 4, Int(lhs[3] ?? "") ?? 0, lhs[0] ?? "")
            let right = (rank[rhs[2] ?? ""] ?? 4, Int(rhs[3] ?? "") ?? 0, rhs[0] ?? "")
            return left < right
        }
        .compactMap { row in row[0].map { ColumnInfo(name: $0, dataType: row[1] ?? "") } }
    }

    func rows(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) async throws -> QueryResult {
        let plan = CQLFilterQuery(object: object, columns: columns, rules: rules, limit: limit).plan()
        let bindings: [CassandraClient.Statement.Value] = plan.bindings.map { value in
            switch value {
            case .text(let string): .string(string)
            case .int32(let int): .int32(int)
            case .int64(let int): .int64(int)
            case .double(let double): .double(double)
            case .bool(let bool): .bool(bool)
            }
        }
        var values = try await query(plan.cql, bindings, textColumns: columns.count)
        if !plan.clientRules.isEmpty {
            let evaluator = RowFilterEvaluator(columns: columns, rules: plan.clientRules)
            values = Array(values.filter(evaluator.matches).prefix(limit))
        }
        return QueryResult(columns: columns, values: values)
    }

    nonisolated func queryPreview(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) -> String? {
        let plan = CQLFilterQuery(object: object, columns: columns, rules: rules, limit: limit).plan()
        return plan.clientRules.isEmpty ? plan.cql : "\(plan.cql)  — \(plan.clientRules.count) rule(s) applied client-side"
    }

    func close() async {
        if let owner {
            self.owner = nil
            await owner.shutdown()
        }
    }

    /// Runs CQL and reads the first `textColumns` result columns as text (or `int`, e.g. `position`).
    private func query(_ cql: String, _ parameters: [CassandraClient.Statement.Value] = [], textColumns: Int = 2) async throws -> [[String?]] {
        let client = try activeClient()
        do {
            let statement = try CassandraClient.Statement(query: cql, parameters: parameters)
            let rows = try await client.execute(statement: statement)
            var values: [[String?]] = []
            for row in rows {
                values.append((0..<textColumns).map { index in
                    let string: String? = row.column(index)
                    if let string { return string }
                    let int: Int32? = row.column(index)
                    return int.map(String.init)
                })
            }
            return values
        } catch {
            AppLog.database.error("Cassandra query failed: \(String(reflecting: error), privacy: .private)")
            throw DatabaseError.queryFailed
        }
    }

    private func activeClient() throws -> CassandraClient {
        if let owner { return owner.client }
        let host = endpoint.host
        var configuration = CassandraClient.Configuration(
            contactPointsProvider: { callback in callback(.success([host])) },
            port: Int32(endpoint.port),
            protocolVersion: .v4
        )
        configuration.username = endpoint.username
        configuration.password = endpoint.password
        configuration.connectTimeoutMillis = 10_000
        let created = CassandraClientOwner(client: CassandraClient(
            eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton), configuration: configuration
        ))
        owner = created
        return created.client
    }
}

/// `CassandraClient` traps (precondition) if released without `shutdown()`; this owner
/// guarantees shutdown even when a window closes without disconnecting.
private nonisolated final class CassandraClientOwner: @unchecked Sendable {
    let client: CassandraClient
    private let lock = NSLock()
    private var isShutDown = false

    init(client: CassandraClient) {
        self.client = client
    }

    func shutdown() async {
        guard markShutDown() else { return }
        try? await client.shutdownAsync()
    }

    deinit {
        if markShutDown() { try? client.shutdown() }
    }

    private func markShutDown() -> Bool {
        lock.withLock {
            defer { isShutDown = true }
            return !isShutDown
        }
    }
}

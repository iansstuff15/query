import Foundation
import os

/// Redis / Valkey. Logical databases (`db0`…) are the objects; each lists keys with type, TTL
/// and a value preview. Key-name filters become a `SCAN MATCH` glob; everything else is
/// evaluated client-side with the same rules as SQL engines.
actor RedisDatabaseClient: DatabaseClient {
    static let columns = [
        ColumnInfo(name: "key", dataType: ""),
        ColumnInfo(name: "type", dataType: ""),
        ColumnInfo(name: "ttl", dataType: ""),
        ColumnInfo(name: "value", dataType: ""),
    ]
    private static let maxScanned = 20_000
    private static let previewItems = 20

    private let endpoint: ServerEndpoint
    private var connection: RESPConnection?
    private var selectedDatabase: Int?

    init(endpoint: ServerEndpoint) {
        self.endpoint = endpoint
    }

    func listObjects() async throws -> [DatabaseObject] {
        var databases = Self.keyspaceDatabases(fromInfo: try await run(["INFO", "keyspace"]).string ?? "")
        databases.insert(Int(endpoint.database ?? "0") ?? 0)
        return databases.sorted().map { DatabaseObject(schema: "redis", name: "db\($0)", kind: .keyspace) }
    }

    /// Database numbers from `INFO keyspace` (`db3:keys=1,expires=0,…` lines, CRLF-separated).
    static func keyspaceDatabases(fromInfo info: String) -> Set<Int> {
        Set(info.split(whereSeparator: \.isNewline).compactMap { line -> Int? in
            guard line.hasPrefix("db"), let colon = line.firstIndex(of: ":") else { return nil }
            return Int(line[line.index(line.startIndex, offsetBy: 2)..<colon])
        })
    }

    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] {
        Self.columns
    }

    func rows(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) async throws -> QueryResult {
        try await select(Int(object.name.dropFirst(2)) ?? 0)
        let evaluator = RowFilterEvaluator(columns: Self.columns, rules: rules)
        let pattern = Self.matchPattern(for: rules)
        var cursor = "0"
        var scanned = 0
        var values: [[String?]] = []
        repeat {
            let reply = try await run(["SCAN", cursor, "MATCH", pattern, "COUNT", "500"]).array
            guard reply.count == 2, let next = reply[0].string else { throw DatabaseError.protocolViolation }
            cursor = next
            let keys = reply[1].array.compactMap(\.string)
            scanned += keys.count
            for key in keys where values.count < limit {
                let row = try await describe(key)
                if evaluator.matches(row) { values.append(row) }
            }
        } while cursor != "0" && values.count < limit && scanned < Self.maxScanned
        return QueryResult(columns: Self.columns, values: values.sorted { ($0[0] ?? "") < ($1[0] ?? "") })
    }

    nonisolated func queryPreview(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) -> String? {
        "SELECT \(object.name.dropFirst(2)); SCAN 0 MATCH \(Self.matchPattern(for: rules)) COUNT 500"
    }

    func close() async {
        await connection?.close()
        connection = nil
    }

    /// A SCAN glob from rules on the `key` column; `*` when none apply.
    static func matchPattern(for rules: [FilterRule]) -> String {
        guard let rule = rules.first(where: { $0.isActive && $0.column == "key" }) else { return "*" }
        let escaped = rule.value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "*", with: "\\*").replacingOccurrences(of: "?", with: "\\?")
            .replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
        switch rule.filterOperator {
        case .equals: return escaped
        case .beginsWith: return "\(escaped)*"
        case .endsWith: return "*\(escaped)"
        case .contains: return "*\(escaped)*"
        default: return "*"
        }
    }

    private func describe(_ key: String) async throws -> [String?] {
        let type = try await run(["TYPE", key]).string ?? "none"
        let ttl = try await run(["TTL", key]).string ?? "-1"
        let preview: String?
        let last = String(Self.previewItems - 1)
        switch type {
        case "string": preview = try await run(["GET", key]).string
        case "hash": preview = Self.json(pairs: try await run(["HGETALL", key]).array.compactMap(\.string))
        case "list": preview = Self.json(list: try await run(["LRANGE", key, "0", last]).array.compactMap(\.string))
        case "set": preview = Self.json(list: try await run(["SRANDMEMBER", key, String(Self.previewItems)]).array.compactMap(\.string).sorted())
        case "zset": preview = Self.json(pairs: try await run(["ZRANGE", key, "0", last, "WITHSCORES"]).array.compactMap(\.string))
        case "stream": preview = try await run(["XLEN", key]).string.map { "\($0) entries" }
        default: preview = nil
        }
        return [key, type, ttl, preview]
    }

    private func select(_ database: Int) async throws {
        guard selectedDatabase != database else { return }
        _ = try await run(["SELECT", String(database)])
        selectedDatabase = database
    }

    private func run(_ arguments: [String]) async throws -> RESPValue {
        let connection = try await activeConnection()
        do {
            return try await connection.command(arguments)
        } catch let error as RESPError {
            AppLog.database.error("Redis \(arguments.first ?? "", privacy: .public) failed: \(error.message, privacy: .private)")
            throw DatabaseError.queryFailed
        } catch {
            AppLog.database.error("Redis I/O failed: \(String(reflecting: error), privacy: .private)")
            self.connection = nil
            selectedDatabase = nil
            throw DatabaseError.connectionFailed
        }
    }

    private func activeConnection() async throws -> RESPConnection {
        if let connection { return connection }
        let stream = TCPStream(
            host: endpoint.host, port: endpoint.port,
            useTLS: endpoint.tlsMode != .disable, verifyCertificate: endpoint.tlsMode == .require
        )
        let opened = RESPConnection(stream: stream)
        do {
            try await opened.open()
            if let password = endpoint.password {
                _ = try await opened.command(endpoint.username.map { ["AUTH", $0, password] } ?? ["AUTH", password])
            }
        } catch {
            AppLog.database.error("Redis connection failed: \(String(reflecting: error), privacy: .private)")
            await opened.close()
            throw DatabaseError.connectionFailed
        }
        connection = opened
        return opened
    }

    private static func json(list: [String]) -> String? {
        JSONText.text(list)
    }

    private static func json(pairs: [String]) -> String? {
        var object: [String: String] = [:]
        stride(from: 0, to: pairs.count - 1, by: 2).forEach { object[pairs[$0]] = pairs[$0 + 1] }
        return JSONText.text(object)
    }
}

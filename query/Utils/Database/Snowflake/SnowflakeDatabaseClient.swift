import Foundation

/// Snowflake SQL API v2 with a programmatic access token (or OAuth token) as bearer.
nonisolated struct SnowflakeDatabaseClient: SQLExecuting {
    let account: String
    let token: String
    let database: String?
    let schema: String?
    let warehouse: String?
    let role: String?
    let api: any APIClient
    /// Delay between polls of a still-running (HTTP 202) statement.
    var pollInterval: Duration = .milliseconds(500)

    var dialect: any SQLDialect { SnowflakeDialect() }
    func objectsStatement() -> SQLStatement { SnowflakeCatalogQueries.objects }
    func columnsStatement(of object: DatabaseObject) -> SQLStatement { SnowflakeCatalogQueries.columns(of: object) }

    var baseURL: URL? {
        let host = account.contains(".snowflakecomputing.com") ? account : "\(account).snowflakecomputing.com"
        return URL(string: "https://\(host)/api/v2/statements")
    }

    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        guard let url = baseURL else { throw DatabaseError.missingConfiguration }
        var body: [String: Any] = ["statement": statement.sql, "timeout": 60]
        body["database"] = database
        body["schema"] = schema
        body["warehouse"] = warehouse
        body["role"] = role
        if !statement.bindings.isEmpty {
            body["bindings"] = Dictionary(uniqueKeysWithValues: statement.bindings.enumerated().map {
                ("\($0.offset + 1)", ["type": "TEXT", "value": $0.element])
            })
        }
        let request = try URLRequest.jsonPost(url, body: body, headers: headers)
        var response = try await api.json(request, engine: "Snowflake")
        // 202: still running; poll the statement handle.
        var attempts = 0
        while response["data"] == nil, let handle = response["statementHandle"] as? String, attempts < 30 {
            attempts += 1
            try await Task.sleep(for: pollInterval)
            var poll = URLRequest(url: url.appending(path: handle))
            headers.forEach { poll.setValue($0.value, forHTTPHeaderField: $0.key) }
            response = try await api.json(poll, engine: "Snowflake")
        }
        guard let data = response["data"] as? [[Any]] else { throw DatabaseError.queryFailed }
        return data.map { $0.map(JSONText.text) }
    }

    private var headers: [String: String] {
        [
            "Authorization": "Bearer \(token)",
            "Accept": "application/json",
            "X-Snowflake-Authorization-Token-Type": token.split(separator: ".").count == 3 ? "KEYPAIR_JWT" : "PROGRAMMATIC_ACCESS_TOKEN",
        ]
    }
}

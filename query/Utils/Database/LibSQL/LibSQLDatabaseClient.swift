import Foundation

/// libSQL / Turso over the Hrana-over-HTTP `v2/pipeline` endpoint.
nonisolated struct LibSQLDatabaseClient: SQLExecuting {
    let baseURL: URL
    let token: String?
    let api: any APIClient

    var dialect: any SQLDialect { SQLiteDialect() }
    func objectsStatement() -> SQLStatement { SQLiteCatalogQueries.objects }
    func columnsStatement(of object: DatabaseObject) -> SQLStatement { SQLiteCatalogQueries.columns(of: object) }

    /// `libsql://` and `wss://` URLs map to their HTTPS equivalents.
    static func httpURL(from raw: String) -> URL? {
        guard var components = URLComponents(string: raw) else { return nil }
        switch components.scheme?.lowercased() {
        case "libsql", "wss", "https": components.scheme = "https"
        case "ws", "http": components.scheme = "http"
        default: return nil
        }
        return components.url
    }

    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        let args = statement.bindings.map { ["type": "text", "value": $0] }
        let body: [String: Any] = [
            "requests": [
                ["type": "execute", "stmt": ["sql": statement.sql, "args": args]],
                ["type": "close"],
            ],
        ]
        var headers: [String: String] = [:]
        if let token { headers["Authorization"] = "Bearer \(token)" }
        let request = try URLRequest.jsonPost(baseURL.appending(path: "v2/pipeline"), body: body, headers: headers)
        let response = try await api.json(request, engine: "libSQL")
        guard let first = (response["results"] as? [[String: Any]])?.first else { throw DatabaseError.protocolViolation }
        guard first["type"] as? String == "ok",
              let result = (first["response"] as? [String: Any])?["result"] as? [String: Any],
              let rows = result["rows"] as? [[[String: Any]]] else {
            throw DatabaseError.queryFailed
        }
        return rows.map { row in row.map { cell in cell["type"] as? String == "null" ? nil : JSONText.text(cell["value"]) } }
    }
}

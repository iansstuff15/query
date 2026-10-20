import Foundation

/// Cloudflare D1 through the REST API's `/raw` query endpoint (keeps column order).
nonisolated struct CloudflareD1DatabaseClient: SQLExecuting {
    let accountID: String
    let databaseID: String
    let token: String
    let api: any APIClient
    var baseURL = URL(string: "https://api.cloudflare.com/client/v4")

    var dialect: any SQLDialect { SQLiteDialect() }
    func objectsStatement() -> SQLStatement { SQLiteCatalogQueries.objects }
    func columnsStatement(of object: DatabaseObject) -> SQLStatement { SQLiteCatalogQueries.columns(of: object) }

    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        guard let url = baseURL?.appending(path: "accounts/\(accountID)/d1/database/\(databaseID)/raw") else {
            throw DatabaseError.missingConfiguration
        }
        let request = try URLRequest.jsonPost(
            url,
            body: ["sql": statement.sql, "params": statement.bindings],
            headers: ["Authorization": "Bearer \(token)"]
        )
        let response = try await api.json(request, engine: "Cloudflare D1")
        guard response["success"] as? Bool == true,
              let first = (response["result"] as? [[String: Any]])?.first,
              let results = first["results"] as? [String: Any],
              let rows = results["rows"] as? [[Any]] else {
            throw DatabaseError.queryFailed
        }
        return rows.map { $0.map(JSONText.text) }
    }
}

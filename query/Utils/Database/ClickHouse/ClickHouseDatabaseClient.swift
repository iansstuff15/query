import Foundation

/// ClickHouse HTTP interface (port 8123/8443) with server-side query parameters.
nonisolated struct ClickHouseDatabaseClient: SQLExecuting {
    let endpoint: ServerEndpoint
    let api: any APIClient

    var dialect: any SQLDialect { ClickHouseDialect() }
    func objectsStatement() -> SQLStatement { ClickHouseCatalogQueries.objects }
    func columnsStatement(of object: DatabaseObject) -> SQLStatement { ClickHouseCatalogQueries.columns(of: object) }

    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        var components = URLComponents()
        components.scheme = endpoint.tlsMode == .disable ? "http" : "https"
        components.host = endpoint.host
        components.port = endpoint.port
        components.path = "/"
        var items = [URLQueryItem(name: "default_format", value: "JSONCompact")]
        if let database = endpoint.database { items.append(URLQueryItem(name: "database", value: database)) }
        items += statement.bindings.enumerated().map { URLQueryItem(name: "param_p\($0.offset + 1)", value: $0.element) }
        components.queryItems = items
        guard let url = components.url else { throw DatabaseError.missingConfiguration }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(statement.sql.utf8)
        request.setValue(endpoint.username ?? "default", forHTTPHeaderField: "X-ClickHouse-User")
        if let password = endpoint.password { request.setValue(password, forHTTPHeaderField: "X-ClickHouse-Key") }
        let response = try await api.json(request, engine: "ClickHouse")
        guard let data = response["data"] as? [[Any]] else { throw DatabaseError.protocolViolation }
        return data.map { $0.map(JSONText.text) }
    }
}

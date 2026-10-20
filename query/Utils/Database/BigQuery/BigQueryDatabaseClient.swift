import Foundation

/// BigQuery REST API v2. Uses a service-account key, or no auth for a local emulator endpoint.
nonisolated struct BigQueryDatabaseClient: SQLExecuting {
    let projectID: String
    let dataset: String?
    let endpoint: URL
    let tokenProvider: GoogleServiceAccountTokenProvider?
    let api: any APIClient

    static let defaultEndpoint = URL(string: "https://bigquery.googleapis.com")

    var dialect: any SQLDialect { BigQueryDialect() }

    /// Not used: listing goes through the REST catalog endpoints instead of SQL.
    func objectsStatement() -> SQLStatement { SQLStatement(sql: "") }
    func columnsStatement(of object: DatabaseObject) -> SQLStatement { SQLStatement(sql: "") }

    func listObjects() async throws -> [DatabaseObject] {
        let datasets: [String]
        if let dataset {
            datasets = [dataset]
        } else {
            let response = try await get("datasets")
            datasets = (response["datasets"] as? [[String: Any]] ?? []).compactMap {
                ($0["datasetReference"] as? [String: Any])?["datasetId"] as? String
            }
        }
        var objects: [DatabaseObject] = []
        for dataset in datasets {
            let response = try await get("datasets/\(dataset)/tables")
            for table in response["tables"] as? [[String: Any]] ?? [] {
                guard let name = (table["tableReference"] as? [String: Any])?["tableId"] as? String else { continue }
                let kind: DatabaseObjectKind = switch table["type"] as? String {
                case "VIEW": .view
                case "MATERIALIZED_VIEW": .materializedView
                default: .table
                }
                objects.append(DatabaseObject(schema: dataset, name: name, kind: kind))
            }
        }
        return objects.sorted { $0.id < $1.id }
    }

    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] {
        let response = try await get("datasets/\(object.schema)/tables/\(object.name)")
        let fields = (response["schema"] as? [String: Any])?["fields"] as? [[String: Any]] ?? []
        return fields.compactMap { field in
            guard let name = field["name"] as? String else { return nil }
            let type = field["type"] as? String ?? ""
            // Repeated / record fields can't be CAST from a string parameter.
            let castable = field["mode"] as? String == "REPEATED" || ["RECORD", "STRUCT"].contains(type) ? "" : Self.standardType(type)
            return ColumnInfo(name: name, dataType: castable)
        }
    }

    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        var body: [String: Any] = ["query": statement.sql, "useLegacySql": false, "timeoutMs": 60_000]
        if let dataset { body["defaultDataset"] = ["projectId": projectID, "datasetId": dataset] }
        if !statement.bindings.isEmpty {
            body["parameterMode"] = "NAMED"
            body["queryParameters"] = statement.bindings.enumerated().map { offset, value in
                ["name": "p\(offset + 1)", "parameterType": ["type": "STRING"], "parameterValue": ["value": value]]
            }
        }
        var request = try URLRequest.jsonPost(url("queries"), body: body)
        try await authorize(&request)
        let response = try await api.json(request, engine: "BigQuery")
        guard response["jobComplete"] as? Bool != false else { throw DatabaseError.queryFailed }
        let rows = response["rows"] as? [[String: Any]] ?? []
        return rows.map { row in
            (row["f"] as? [[String: Any]] ?? []).map { JSONText.text($0["v"]) }
        }
    }

    /// Legacy REST type names → GoogleSQL names usable in CAST.
    static func standardType(_ type: String) -> String {
        switch type {
        case "INTEGER": "INT64"
        case "FLOAT": "FLOAT64"
        case "BOOLEAN": "BOOL"
        default: type
        }
    }

    private func url(_ path: String) -> URL {
        endpoint.appending(path: "bigquery/v2/projects/\(projectID)/\(path)")
    }

    private func get(_ path: String) async throws -> [String: Any] {
        var request = URLRequest(url: url(path))
        try await authorize(&request)
        return try await api.json(request, engine: "BigQuery")
    }

    private func authorize(_ request: inout URLRequest) async throws {
        guard let tokenProvider else { return }
        request.setValue("Bearer \(try await tokenProvider.accessToken())", forHTTPHeaderField: "Authorization")
    }
}

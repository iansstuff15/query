import Foundation

/// Elasticsearch / OpenSearch REST API. Indices are objects; mapping fields are columns
/// (nested objects flattened with dots); filters become Query DSL.
nonisolated struct ElasticsearchDatabaseClient: DatabaseClient {
    let baseURL: URL
    let username: String?
    let password: String?
    let api: any APIClient

    /// `_resolve/index` needs only `view_index_metadata`, so read-only users can list indices;
    /// `_cat/indices` (needs `monitor`) is the fallback for older clusters and OpenSearch.
    func listObjects() async throws -> [DatabaseObject] {
        let names: [String]
        if let resolved = try? await api.json(request("_resolve/index/*"), engine: "Elasticsearch") {
            names = (resolved["indices"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }
        } else {
            let data = try await api.checkedData(request("_cat/indices", query: [URLQueryItem(name: "format", value: "json")]), engine: "Elasticsearch")
            guard let indices = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw DatabaseError.protocolViolation
            }
            names = indices.compactMap { $0["index"] as? String }
        }
        return names.filter { !$0.hasPrefix(".") }.sorted()
            .map { DatabaseObject(schema: "indices", name: $0, kind: .index) }
    }

    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] {
        let response = try await api.json(request("\(object.name)/_mapping"), engine: "Elasticsearch")
        let mapping = (response[object.name] as? [String: Any])?["mappings"] as? [String: Any]
        return [ColumnInfo(name: "_id", dataType: "keyword")] + Self.flatten(mapping?["properties"] as? [String: Any] ?? [:], prefix: "")
    }

    func rows(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) async throws -> QueryResult {
        var request = try URLRequest.jsonPost(
            url("\(object.name)/_search"),
            body: ["size": limit, "query": ElasticsearchFilterQuery(rules: rules, columns: columns).query()]
        )
        authorize(&request)
        let response = try await api.json(request, engine: "Elasticsearch")
        let hits = (response["hits"] as? [String: Any])?["hits"] as? [[String: Any]] ?? []
        return QueryResult(columns: columns, values: hits.map { hit in
            let source = hit["_source"] as? [String: Any] ?? [:]
            return columns.map { column in
                column.name == "_id" ? hit["_id"] as? String : JSONText.text(Self.value(at: column.name, in: source))
            }
        })
    }

    func queryPreview(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) -> String? {
        let body: [String: Any] = ["size": limit, "query": ElasticsearchFilterQuery(rules: rules, columns: columns).query()]
        return "POST /\(object.name)/_search \(JSONText.text(body) ?? "")"
    }

    static func flatten(_ properties: [String: Any], prefix: String) -> [ColumnInfo] {
        properties.keys.sorted().flatMap { key -> [ColumnInfo] in
            guard let field = properties[key] as? [String: Any] else { return [] }
            let name = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let nested = field["properties"] as? [String: Any] {
                return flatten(nested, prefix: name)
            }
            var type = field["type"] as? String ?? "object"
            if type == "text", ((field["fields"] as? [String: Any])?["keyword"]) != nil { type += "+keyword" }
            return [ColumnInfo(name: name, dataType: type)]
        }
    }

    static func value(at path: String, in source: [String: Any]) -> Any? {
        if let direct = source[path] { return direct }
        var current: Any? = source
        for part in path.split(separator: ".") {
            current = (current as? [String: Any])?[String(part)]
        }
        return current
    }

    private func url(_ path: String) -> URL {
        baseURL.appending(path: path)
    }

    private func request(_ path: String, query: [URLQueryItem] = []) -> URLRequest {
        var request = URLRequest(url: query.isEmpty ? url(path) : url(path).appending(queryItems: query))
        authorize(&request)
        return request
    }

    private func authorize(_ request: inout URLRequest) {
        guard let username else { return }
        let credentials = Data("\(username):\(password ?? "")".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
    }
}

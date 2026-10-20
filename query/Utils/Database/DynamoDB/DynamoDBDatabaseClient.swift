import Foundation

/// Amazon DynamoDB JSON API (or DynamoDB Local) signed with SigV4. Tables are objects;
/// key attributes plus attributes seen in a sample are columns; rows come from `Scan`.
nonisolated struct DynamoDBDatabaseClient: DatabaseClient {
    private static let sampleSize = 100
    private static let maxScanned = 10_000

    let endpoint: URL
    let signer: AWSSigV4Signer
    let api: any APIClient
    var now: @Sendable () -> Date = Date.init

    static func defaultEndpoint(region: String) -> URL? {
        URL(string: "https://dynamodb.\(region).amazonaws.com")
    }

    func listObjects() async throws -> [DatabaseObject] {
        var names: [String] = []
        var start: String?
        repeat {
            var body: [String: Any] = [:]
            body["ExclusiveStartTableName"] = start
            let response = try await call("ListTables", body)
            names += response["TableNames"] as? [String] ?? []
            start = response["LastEvaluatedTableName"] as? String
        } while start != nil
        return names.sorted().map { DatabaseObject(schema: signer.region, name: $0, kind: .table) }
    }

    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] {
        let description = try await call("DescribeTable", ["TableName": object.name])
        let table = description["Table"] as? [String: Any] ?? [:]
        var types: [String: String] = [:]
        for attribute in table["AttributeDefinitions"] as? [[String: Any]] ?? [] {
            if let name = attribute["AttributeName"] as? String { types[name] = attribute["AttributeType"] as? String }
        }
        let keys = (table["KeySchema"] as? [[String: Any]] ?? [])
            .sorted { ($0["KeyType"] as? String ?? "") > ($1["KeyType"] as? String ?? "") }
            .compactMap { $0["AttributeName"] as? String }
        let sample = try await call("Scan", ["TableName": object.name, "Limit": Self.sampleSize])
        var others: [String] = []
        for item in sample["Items"] as? [[String: Any]] ?? [] {
            for (name, value) in item where !keys.contains(name) && types[name] == nil {
                types[name] = (value as? [String: Any])?.keys.first
                others.append(name)
            }
        }
        return (keys + others.sorted()).map { ColumnInfo(name: $0, dataType: types[$0] ?? "") }
    }

    func rows(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) async throws -> QueryResult {
        let types = Dictionary(uniqueKeysWithValues: columns.map { ($0.name, $0.dataType) })
        let expression = DynamoDBFilterQuery(rules: rules, attributeTypes: types).expression()
        let evaluator = RowFilterEvaluator(columns: columns, rules: rules)
        var values: [[String?]] = []
        var startKey: Any?
        var scanned = 0
        repeat {
            var body: [String: Any] = ["TableName": object.name, "Limit": 500]
            if let filter = expression.filter {
                body["FilterExpression"] = filter
                body["ExpressionAttributeNames"] = expression.names
                if !expression.values.isEmpty { body["ExpressionAttributeValues"] = expression.values }
            }
            body["ExclusiveStartKey"] = startKey
            let response = try await call("Scan", body)
            scanned += response["ScannedCount"] as? Int ?? 0
            for item in response["Items"] as? [[String: Any]] ?? [] {
                let row = columns.map { Self.text(item[$0.name]) }
                if evaluator.matches(row) { values.append(row) }
                if values.count >= limit { break }
            }
            startKey = response["LastEvaluatedKey"]
        } while startKey != nil && values.count < limit && scanned < Self.maxScanned
        return QueryResult(columns: columns, values: values)
    }

    func queryPreview(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) -> String? {
        let types = Dictionary(uniqueKeysWithValues: columns.map { ($0.name, $0.dataType) })
        let expression = DynamoDBFilterQuery(rules: rules, attributeTypes: types).expression()
        guard let filter = expression.filter else { return "Scan \(object.name)" }
        return "Scan \(object.name) FilterExpression: \(filter)  — names \(JSONText.text(expression.names) ?? ""), values \(JSONText.text(expression.values) ?? "")"
    }

    /// Renders an `AttributeValue` (`{"S": "x"}`, `{"N": "1"}`, `{"M": {…}}`, …) as text.
    static func text(_ attribute: Any?) -> String? {
        guard let attribute = attribute as? [String: Any], let (type, value) = attribute.first else { return nil }
        switch type {
        case "NULL": return nil
        case "S", "N", "B": return value as? String
        case "BOOL": return JSONText.text(value)
        case "SS", "NS", "BS": return JSONText.text(value)
        case "L": return JSONText.text((value as? [Any] ?? []).map { plain($0) })
        case "M": return JSONText.text((value as? [String: Any] ?? [:]).mapValues { plain($0) })
        default: return JSONText.text(value)
        }
    }

    private static func plain(_ attribute: Any) -> Any {
        guard let attribute = attribute as? [String: Any], let (type, value) = attribute.first else { return NSNull() }
        switch type {
        case "NULL": return NSNull()
        case "N": return Double(value as? String ?? "") ?? value
        case "L": return (value as? [Any] ?? []).map(plain)
        case "M": return (value as? [String: Any] ?? [:]).mapValues(plain)
        default: return value
        }
    }

    private func call(_ operation: String, _ body: [String: Any]) async throws -> [String: Any] {
        let data = try JSONText.body(body)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/x-amz-json-1.0", forHTTPHeaderField: "Content-Type")
        request.setValue("DynamoDB_20120810.\(operation)", forHTTPHeaderField: "X-Amz-Target")
        signer.sign(&request, body: data, date: now())
        return try await api.json(request, engine: "DynamoDB")
    }
}

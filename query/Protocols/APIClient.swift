import Foundation

/// HTTP transport for HTTP-based engines (ClickHouse, Elasticsearch, DynamoDB, BigQuery, …).
nonisolated protocol APIClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

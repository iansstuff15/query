import Foundation

/// Maps each engine to its driver and transport.
nonisolated struct DefaultDatabaseClientFactory: DatabaseClientFactory {
    var api: any APIClient = URLSessionAPIClient()

    func makeClient(for draft: ConnectionDraft) throws -> any DatabaseClient {
        switch draft.engine {
        case .vertica:
            return VerticaDatabaseClient(endpoint: try ServerEndpoint(draft: draft))
        case .postgreSQL, .cockroachDB, .greenplum, .redshift:
            guard let flavor = PostgresFlavor(engine: draft.engine) else { throw DatabaseError.unsupported }
            return PostgresDatabaseClient(endpoint: try ServerEndpoint(draft: draft), flavor: flavor)
        case .mySQL, .mariaDB:
            return MySQLDatabaseClient(endpoint: try ServerEndpoint(draft: draft))
        case .sqlServer:
            return SQLServerDatabaseClient(endpoint: try ServerEndpoint(draft: draft))
        case .oracle:
            return OracleDatabaseClient(endpoint: try ServerEndpoint(draft: draft))
        case .sqlite:
            return SQLiteDatabaseClient(fileURL: try fileURL(draft))
        case .duckDB:
            return DuckDBDatabaseClient(fileURL: try fileURL(draft))
        case .clickHouse:
            return ClickHouseDatabaseClient(endpoint: try ServerEndpoint(draft: draft), api: api)
        case .libSQL:
            guard let raw = draft.value(.url), let url = LibSQLDatabaseClient.httpURL(from: raw) else {
                throw DatabaseError.missingConfiguration
            }
            return LibSQLDatabaseClient(baseURL: url, token: draft.value(.apiToken), api: api)
        case .cloudflareD1:
            guard let account = draft.value(.accountID), let database = draft.value(.databaseID), let token = draft.value(.apiToken) else {
                throw DatabaseError.missingConfiguration
            }
            return CloudflareD1DatabaseClient(accountID: account, databaseID: database, token: token, api: api)
        case .bigQuery:
            guard let project = draft.value(.projectID) else { throw DatabaseError.missingConfiguration }
            let endpoint = draft.value(.endpoint).flatMap(URL.init(string:)) ?? BigQueryDatabaseClient.defaultEndpoint
            guard let endpoint else { throw DatabaseError.missingConfiguration }
            let tokens = draft.value(.serviceAccountJSON).map { GoogleServiceAccountTokenProvider(keyJSON: $0, api: api) }
            if tokens == nil, draft.value(.endpoint) == nil { throw DatabaseError.missingConfiguration }
            return BigQueryDatabaseClient(projectID: project, dataset: draft.value(.dataset), endpoint: endpoint, tokenProvider: tokens, api: api)
        case .snowflake:
            guard let account = draft.value(.account), let token = draft.value(.apiToken) else { throw DatabaseError.missingConfiguration }
            return SnowflakeDatabaseClient(
                account: account, token: token, database: draft.value(.database), schema: draft.value(.schema),
                warehouse: draft.value(.warehouse), role: draft.value(.role), api: api
            )
        case .cassandra:
            return CassandraDatabaseClient(endpoint: try ServerEndpoint(draft: draft))
        case .redis:
            return RedisDatabaseClient(endpoint: try ServerEndpoint(draft: draft))
        case .mongoDB:
            guard let url = draft.value(.url) else { throw DatabaseError.missingConfiguration }
            return MongoDatabaseClient(connectionString: url)
        case .elasticsearch:
            guard let url = draft.value(.url).flatMap(URL.init(string:)) else { throw DatabaseError.missingConfiguration }
            return ElasticsearchDatabaseClient(baseURL: url, username: draft.value(.username), password: draft.value(.password), api: api)
        case .dynamoDB:
            guard let region = draft.value(.region), let access = draft.value(.accessKeyID), let secret = draft.value(.secretAccessKey),
                  let endpoint = draft.value(.endpoint).flatMap(URL.init(string:)) ?? DynamoDBDatabaseClient.defaultEndpoint(region: region) else {
                throw DatabaseError.missingConfiguration
            }
            let signer = AWSSigV4Signer(accessKeyID: access, secretAccessKey: secret, region: region, service: "dynamodb")
            return DynamoDBDatabaseClient(endpoint: endpoint, signer: signer, api: api)
        }
    }

    private func fileURL(_ draft: ConnectionDraft) throws -> URL {
        if let bookmark = draft.value(.fileBookmark).flatMap({ Data(base64Encoded: $0) }) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale) {
                return url
            }
        }
        guard let path = draft.value(.filePath) else { throw DatabaseError.missingConfiguration }
        return URL(filePath: (path as NSString).expandingTildeInPath)
    }
}

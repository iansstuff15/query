import Foundation

/// Engine metadata. Field lists mirror TablePlus's per-engine connection forms.
nonisolated enum EngineCatalog {
    private static let serverFields: [ConnectionField] = [.host, .port, .username, .password, .database, .tlsMode]

    static let all: [EngineDescriptor] = DatabaseEngine.allCases.map(makeDescriptor)

    static func descriptor(for engine: DatabaseEngine) -> EngineDescriptor {
        makeDescriptor(engine)
    }

    // swiftlint:disable:next function_body_length
    private static func makeDescriptor(_ engine: DatabaseEngine) -> EngineDescriptor {
        switch engine {
        case .postgreSQL:
            server(engine, "PostgreSQL", "cylinder.split.1x2", .postgres, port: 5_432, user: "postgres",
                   url: "postgresql://user:password@localhost:5432/app?sslmode=prefer")
        case .cockroachDB:
            server(engine, "CockroachDB", "ant", .postgres, port: 26_257, user: "root", database: "defaultdb",
                   url: "postgresql://root@localhost:26257/defaultdb?sslmode=disable")
        case .greenplum:
            server(engine, "Greenplum", "g.circle", .postgres, port: 5_432, user: "gpadmin",
                   url: "postgresql://gpadmin:password@localhost:5432/app")
        case .redshift:
            server(engine, "Amazon Redshift", "chart.bar.xaxis", .postgres, port: 5_439, user: "awsuser", database: "dev",
                   url: "redshift://awsuser:password@cluster.region.redshift.amazonaws.com:5439/dev", tls: .require)
        case .vertica:
            server(engine, "Vertica", "v.circle", .postgres, port: 5_433, user: "dbadmin",
                   url: "vertica://dbadmin:password@localhost:5433/app")
        case .mySQL:
            server(engine, "MySQL", "fish", .mySQL, port: 3_306, user: "root",
                   url: "mysql://user:password@localhost:3306/app")
        case .mariaDB:
            server(engine, "MariaDB", "water.waves", .mySQL, port: 3_306, user: "root",
                   url: "mariadb://user:password@localhost:3306/app")
        case .sqlServer:
            server(engine, "Microsoft SQL Server", "server.rack", .sqlServer, port: 1_433, user: "sa", database: "master",
                   url: "Server=localhost,1433;Database=app;User Id=sa;Password=…;Encrypt=False")
        case .oracle:
            EngineDescriptor(
                engine: engine, displayName: "Oracle", systemImage: "o.circle", family: .oracle,
                fields: [.host, .port, .serviceName, .username, .password],
                defaultPort: 1_521, defaultValues: [.host: "localhost", .serviceName: "FREEPDB1"],
                urlExample: "user/password@localhost:1521/FREEPDB1", isURLFirst: false
            )
        case .sqlite:
            file(engine, "SQLite", "doc", .sqlite, url: "sqlite:///Users/me/app.sqlite")
        case .duckDB:
            file(engine, "DuckDB", "bird", .duckDB, url: "duckdb:///Users/me/app.duckdb")
        case .libSQL:
            EngineDescriptor(
                engine: engine, displayName: "libSQL / Turso", systemImage: "externaldrive.connected.to.line.below",
                family: .libSQL, fields: [.url, .apiToken], defaultPort: nil, defaultValues: [:],
                urlExample: "http://localhost:8080 or libsql://db-org.turso.io?authToken=…", isURLFirst: true
            )
        case .cloudflareD1:
            EngineDescriptor(
                engine: engine, displayName: "Cloudflare D1", systemImage: "cloud", family: .cloudflareD1,
                fields: [.accountID, .databaseID, .apiToken], defaultPort: nil, defaultValues: [:],
                urlExample: nil, isURLFirst: false
            )
        case .clickHouse:
            server(engine, "ClickHouse", "bolt", .clickHouse, port: 8_123, user: "default", database: "default",
                   url: "clickhouse://default:password@localhost:8123/app", tls: .disable)
        case .bigQuery:
            EngineDescriptor(
                engine: engine, displayName: "BigQuery", systemImage: "square.grid.3x3", family: .bigQuery,
                fields: [.projectID, .dataset, .serviceAccountJSON, .endpoint], defaultPort: nil, defaultValues: [:],
                urlExample: "bigquery://my-project/my_dataset", isURLFirst: false
            )
        case .snowflake:
            EngineDescriptor(
                engine: engine, displayName: "Snowflake", systemImage: "snowflake", family: .snowflake,
                fields: [.account, .username, .apiToken, .warehouse, .role, .database, .schema],
                defaultPort: nil, defaultValues: [:],
                urlExample: "snowflake://user@account/database/schema?warehouse=WH&role=ROLE", isURLFirst: false
            )
        case .cassandra:
            EngineDescriptor(
                engine: engine, displayName: "Cassandra / ScyllaDB", systemImage: "circle.hexagongrid", family: .cassandra,
                fields: [.host, .port, .username, .password, .keyspace], defaultPort: 9_042,
                defaultValues: [.host: "localhost"],
                urlExample: "cassandra://user:password@localhost:9042/keyspace", isURLFirst: false
            )
        case .redis:
            EngineDescriptor(
                engine: engine, displayName: "Redis / Valkey", systemImage: "memorychip", family: .redis,
                fields: [.host, .port, .username, .password, .database, .tlsMode], defaultPort: 6_379,
                defaultValues: [.host: "localhost", .database: "0", .tlsMode: TLSMode.disable.rawValue],
                urlExample: "redis://:password@localhost:6379/0", isURLFirst: false
            )
        case .mongoDB:
            EngineDescriptor(
                engine: engine, displayName: "MongoDB", systemImage: "leaf", family: .mongoDB,
                fields: [.url], defaultPort: 27_017, defaultValues: [.url: "mongodb://localhost:27017"],
                urlExample: "mongodb://user:password@localhost:27017/app?authSource=admin", isURLFirst: true
            )
        case .elasticsearch:
            EngineDescriptor(
                engine: engine, displayName: "Elasticsearch", systemImage: "text.magnifyingglass", family: .elasticsearch,
                fields: [.url, .username, .password], defaultPort: 9_200, defaultValues: [.url: "http://localhost:9200"],
                urlExample: "https://elastic:password@localhost:9200", isURLFirst: true
            )
        case .dynamoDB:
            EngineDescriptor(
                engine: engine, displayName: "Amazon DynamoDB", systemImage: "bolt.horizontal", family: .dynamoDB,
                fields: [.region, .accessKeyID, .secretAccessKey, .endpoint], defaultPort: nil,
                defaultValues: [.region: "us-east-1"], urlExample: nil, isURLFirst: false
            )
        }
    }

    // swiftlint:disable:next function_parameter_count
    private static func server(
        _ engine: DatabaseEngine, _ name: String, _ symbol: String, _ family: EngineFamily,
        port: Int, user: String, database: String? = nil, url: String, tls: TLSMode = .prefer
    ) -> EngineDescriptor {
        var defaults: [ConnectionField: String] = [.host: "localhost", .username: user, .tlsMode: tls.rawValue]
        defaults[.database] = database
        return EngineDescriptor(
            engine: engine, displayName: name, systemImage: symbol, family: family, fields: serverFields,
            defaultPort: port, defaultValues: defaults, urlExample: url, isURLFirst: false
        )
    }

    private static func file(_ engine: DatabaseEngine, _ name: String, _ symbol: String, _ family: EngineFamily, url: String) -> EngineDescriptor {
        EngineDescriptor(
            engine: engine, displayName: name, systemImage: symbol, family: family, fields: [.filePath],
            defaultPort: nil, defaultValues: [:], urlExample: url, isURLFirst: false
        )
    }
}

import Testing
@testable import query

@Suite("ConnectionStringParser")
struct ConnectionStringParserTests {
    private func parse(_ raw: String, _ engine: DatabaseEngine) throws -> [ConnectionField: String] {
        try ConnectionStringParser.parse(raw, for: engine)
    }

    @Test func postgresURLWithPercentEncodingAndSSLMode() throws {
        let values = try parse("postgresql://ada%40corp:p%40ss@db.internal:6543/app?sslmode=verify-full", .postgreSQL)
        #expect(values == [.host: "db.internal", .port: "6543", .username: "ada@corp", .password: "p@ss", .database: "app", .tlsMode: "require"])
    }

    @Test func jdbcPrefixIsAccepted() throws {
        #expect(try parse("jdbc:postgresql://localhost/app?user=me&password=pw", .postgreSQL)[.username] == "me")
    }

    @Test func schemeMustMatchEngine() {
        #expect(throws: ConnectionStringError.schemeMismatch(expected: ["mysql"], found: "postgres")) {
            try parse("postgres://localhost/app", .mySQL)
        }
        #expect(throws: ConnectionStringError.unsupportedEngine) { try parse("x", .cloudflareD1) }
        #expect(throws: ConnectionStringError.malformed) { try parse("   ", .postgreSQL) }
    }

    @Test(arguments: [
        ("mysql://root:pw@127.0.0.1:3306/app?ssl-mode=DISABLED", DatabaseEngine.mySQL, String?("disable")),
        ("mariadb://root@localhost/app", .mariaDB, nil),
        ("clickhouse://default:pw@localhost:8123/app", .clickHouse, nil),
        ("https://default:pw@ch.cloud:8443/app", .clickHouse, "require"),
        ("redshift://awsuser:pw@cluster.example:5439/dev", .redshift, nil),
        ("vertica://dbadmin@localhost:5433/docker", .vertica, nil),
    ])
    func serverURLs(raw: String, engine: DatabaseEngine, tls: String?) throws {
        let values = try parse(raw, engine)
        #expect(values[.host] != nil)
        #expect(values[.tlsMode] == tls)
    }

    @Test func redisDefaultsDatabaseAndTLSScheme() throws {
        #expect(try parse("redis://:secret@cache:6380", .redis) == [.host: "cache", .port: "6380", .password: "secret", .database: "0"])
        #expect(try parse("rediss://cache/2", .redis)[.tlsMode] == "require")
    }

    @Test func cassandraPathIsKeyspace() throws {
        let values = try parse("cassandra://u:p@node1:9042/app", .cassandra)
        #expect(values[.keyspace] == "app")
        #expect(values[.database] == nil)
    }

    @Test func sqlServerADONetString() throws {
        let values = try parse("Server=tcp:sql.example,14330;Initial Catalog=app;User Id=sa;Password=p;w;Encrypt=True", .sqlServer)
        #expect(values[.host] == "sql.example")
        #expect(values[.port] == "14330")
        #expect(values[.database] == "app")
        #expect(values[.username] == "sa")
        #expect(values[.tlsMode] == "require")
    }

    @Test func sqlServerJDBCAndURL() throws {
        let jdbc = try parse("jdbc:sqlserver://db:1433;databaseName=app;user=sa;password=pw;encrypt=false", .sqlServer)
        #expect(jdbc == [.host: "db", .port: "1433", .database: "app", .username: "sa", .password: "pw", .tlsMode: "disable"])
        #expect(try parse("sqlserver://sa:pw@db:1433/app", .sqlServer)[.database] == "app")
    }

    @Test func oracleFormats() throws {
        #expect(try parse("scott/tiger@db:1521/FREEPDB1", .oracle) == [.username: "scott", .password: "tiger", .host: "db", .port: "1521", .serviceName: "FREEPDB1"])
        #expect(try parse("jdbc:oracle:thin:@//db:1522/ORCL", .oracle) == [.host: "db", .port: "1522", .serviceName: "ORCL"])
        #expect(try parse("jdbc:oracle:thin:@db:1521:XE", .oracle)[.serviceName] == "XE")
        #expect(try parse("oracle://u:p@db:1521/FREEPDB1", .oracle)[.serviceName] == "FREEPDB1")
    }

    @Test func fileEngines() throws {
        #expect(try parse("sqlite:///Users/me/app.sqlite", .sqlite) == [.filePath: "/Users/me/app.sqlite"])
        #expect(try parse("file:/tmp/my%20db.sqlite?mode=ro", .sqlite) == [.filePath: "/tmp/my db.sqlite"])
        #expect(try parse("/tmp/x.duckdb", .duckDB) == [.filePath: "/tmp/x.duckdb"])
        #expect(throws: ConnectionStringError.self) { try parse("duckdb:relative.db", .duckDB) }
    }

    @Test func urlFirstEngines() throws {
        #expect(try parse("mongodb+srv://u:p@cluster0.example.net/app", .mongoDB) == [.url: "mongodb+srv://u:p@cluster0.example.net/app"])
        let libsql = try parse("libsql://db-org.turso.io?authToken=abc", .libSQL)
        #expect(libsql == [.url: "libsql://db-org.turso.io", .apiToken: "abc"])
        let elastic = try parse("https://elastic:pw@es.local:9200", .elasticsearch)
        #expect(elastic == [.url: "https://es.local:9200", .username: "elastic", .password: "pw"])
    }

    @Test func snowflakeAndBigQuery() throws {
        let snowflake = try parse("snowflake://ADA@xy12345.us-east-1/QUERY_TEST/PUBLIC?warehouse=WH&role=READER", .snowflake)
        #expect(snowflake == [.account: "xy12345.us-east-1", .username: "ADA", .database: "QUERY_TEST", .schema: "PUBLIC", .warehouse: "WH", .role: "READER"])
        let bigQuery = try parse("bigquery://query-test/app?endpoint=http://localhost:19050", .bigQuery)
        #expect(bigQuery == [.projectID: "query-test", .dataset: "app", .endpoint: "http://localhost:19050"])
    }
}

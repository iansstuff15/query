import Foundation
import Testing
@testable import query

/// Runs each real driver against its seeded container from `docker/`.
///
/// Opt-in: `TEST_RUNNER_QUERY_LIVE_ENGINES=postgreSQL,mySQL,…` (or `all`) when invoking
/// `xcodebuild test`. SQLite/DuckDB files must first be copied into the app container's tmp
/// directory (`docker/run-live-tests.sh` does this).
@Suite("Live engines", .tags(.integration), .serialized)
struct LiveEngineTests {
    struct Case: CustomTestStringConvertible, Sendable {
        let engine: DatabaseEngine
        let values: [ConnectionField: String]
        let customers: DatabaseObject
        /// Column-name casing (Oracle stores unquoted names in upper case).
        var uppercase = false
        var idColumn = "id"
        var supportsIDRange = true

        var testDescription: String { engine.rawValue }

        func name(_ column: String) -> String { uppercase ? column.uppercased() : column }
    }

    static let enabled: Set<String> = {
        let raw = ProcessInfo.processInfo.environment["QUERY_LIVE_ENGINES"] ?? ""
        return raw == "all" ? Set(DatabaseEngine.allCases.map(\.rawValue)) : Set(raw.split(separator: ",").map(String.init))
    }()

    static let tmp = FileManager.default.temporaryDirectory.path
    static let reader: [ConnectionField: String] = [.host: "localhost", .username: "query_reader", .password: "ReaderPass1", .tlsMode: "disable"]

    static let cases: [Case] = [
        Case(engine: .postgreSQL, values: reader.merging([.port: "55432", .database: "app"]) { $1 },
             customers: .init(schema: "public", name: "customers", kind: .table)),
        Case(engine: .cockroachDB, values: [.host: "localhost", .port: "26257", .username: "query_reader", .database: "app", .tlsMode: "disable"],
             customers: .init(schema: "public", name: "customers", kind: .table)),
        Case(engine: .greenplum, values: reader.merging([.port: "55433", .database: "postgres"]) { $1 },
             customers: .init(schema: "public", name: "customers", kind: .table)),
        Case(engine: .vertica, values: reader.merging([.port: "55434", .database: "testdb"]) { $1 },
             customers: .init(schema: "public", name: "customers", kind: .table)),
        Case(engine: .mySQL, values: reader.merging([.port: "33306", .database: "app", .tlsMode: "prefer"]) { $1 },
             customers: .init(schema: "app", name: "customers", kind: .table)),
        Case(engine: .mariaDB, values: reader.merging([.port: "33307", .database: "app", .tlsMode: "prefer"]) { $1 },
             customers: .init(schema: "app", name: "customers", kind: .table)),
        Case(engine: .sqlServer, values: reader.merging([.port: "14330", .database: "app"]) { $1 },
             customers: .init(schema: "dbo", name: "customers", kind: .table)),
        Case(engine: .oracle, values: reader.merging([.port: "15210", .serviceName: "FREEPDB1"]) { $1 },
             customers: .init(schema: "APP", name: "CUSTOMERS", kind: .table), uppercase: true),
        Case(engine: .clickHouse, values: reader.merging([.port: "18123", .database: "app"]) { $1 },
             customers: .init(schema: "app", name: "customers", kind: .table)),
        Case(engine: .libSQL, values: [.url: "http://localhost:18080"], customers: .init(schema: "main", name: "customers", kind: .table)),
        Case(engine: .sqlite, values: [.filePath: "\(tmp)/app.sqlite"], customers: .init(schema: "main", name: "customers", kind: .table)),
        Case(engine: .duckDB, values: [.filePath: "\(tmp)/app.duckdb"], customers: .init(schema: "main", name: "customers", kind: .table)),
        Case(engine: .bigQuery, values: [.projectID: "query-test", .dataset: "app", .endpoint: "http://localhost:19050"],
             customers: .init(schema: "app", name: "customers", kind: .table)),
        Case(engine: .cassandra, values: reader.merging([.port: "19042", .keyspace: "app"]) { $1 },
             customers: .init(schema: "app", name: "customers", kind: .table)),
        Case(engine: .mongoDB, values: [.url: "mongodb://query_reader:ReaderPass1@localhost:27018/app?authSource=app"],
             customers: .init(schema: "app", name: "customers", kind: .collection), idColumn: "_id"),
        Case(engine: .elasticsearch, values: [.url: "http://localhost:19200", .username: "query_reader", .password: "ReaderPass1"],
             customers: .init(schema: "indices", name: "customers", kind: .index), idColumn: "_id", supportsIDRange: false),
        Case(engine: .dynamoDB, values: [.region: "us-east-1", .accessKeyID: "local", .secretAccessKey: "local", .endpoint: "http://localhost:18000"],
             customers: .init(schema: "us-east-1", name: "customers", kind: .table)),
    ]

    static var activeCases: [Case] { cases.filter { enabled.contains($0.engine.rawValue) } }

    private func client(_ testCase: Case) throws -> any DatabaseClient {
        try DefaultDatabaseClientFactory().makeClient(for: ConnectionDraft(engine: testCase.engine, values: testCase.values))
    }

    @Test(.enabled(if: !activeCases.isEmpty), arguments: activeCases)
    func catalogColumnsAndServerSideFilters(_ testCase: Case) async throws {
        let client = try client(testCase)
        do {
            try await exercise(client, testCase)
            await client.close()
        } catch {
            await client.close()
            throw error
        }
    }

    private func exercise(_ client: any DatabaseClient, _ testCase: Case) async throws {

        let objects = try await client.listObjects()
        #expect(objects.contains(testCase.customers), "objects: \(objects.map(\.id))")

        let columns = try await client.columns(of: testCase.customers)
        #expect(columns.contains { $0.name == testCase.name("email") }, "columns: \(columns)")

        func count(_ rules: [FilterRule]) async throws -> Int {
            try await client.rows(of: testCase.customers, columns: columns, rules: rules, limit: 100).rows.count
        }
        #expect(try await count([]) == 12)
        #expect(try await count([FilterRule(column: testCase.name("email"), filterOperator: .endsWith, value: "example.com")]) == 4)
        #expect(try await count([FilterRule(column: testCase.name("country"), filterOperator: .isNull)]) == 1)
        #expect(try await count([FilterRule(column: nil, filterOperator: .equals, value: "GB")]) == 2)
        #expect(try await count([FilterRule(column: testCase.name("full_name"), filterOperator: .contains, value: "HOPPER")]) == 1)
        #expect(try await count([FilterRule(column: testCase.name("country"), filterOperator: .inList, value: "FI, NL")]) == 2)
        #expect(try await count([FilterRule(column: nil, filterOperator: .contains, value: "100%")]) == 0)
        #expect(try await count([FilterRule(column: nil, filterOperator: .equals, value: "'; DROP TABLE customers; --")]) == 0)
        if testCase.supportsIDRange {
            #expect(try await count([FilterRule(column: testCase.name(testCase.idColumn), filterOperator: .greaterThan, value: "10")]) == 2)
        }
        #expect(try await count([]) == 12, "table still intact")
        #expect(client.queryPreview(of: testCase.customers, columns: columns, rules: [], limit: 1) != nil || testCase.engine == .bigQuery)
    }

    /// Drivers whose SQL console reports real column names and decodes typed values.
    static let namedConsoleEngines: Set<DatabaseEngine> = [.postgreSQL, .cockroachDB, .greenplum, .mySQL, .mariaDB]
    static var consoleCases: [Case] { activeCases.filter { namedConsoleEngines.contains($0.engine) } }

    @Test(.enabled(if: !consoleCases.isEmpty), arguments: consoleCases)
    func sqlConsoleRunsRawSQL(_ testCase: Case) async throws {
        let console = try #require(try client(testCase) as? any SQLConsoleRunning)
        do {
            let result = try await console.runSQL(
                "SELECT id, full_name, country, created_at, price FROM customers JOIN products USING (id) WHERE id IN (1, 3) ORDER BY id"
            )
            #expect(result.columns.map(\.name) == ["id", "full_name", "country", "created_at", "price"])
            #expect(result.rows.map { $0.values[0] } == ["1", "3"])
            #expect(result.rows.first?.values[1] == "Ada Lovelace")
            #expect(result.rows.first?.values[3]?.hasPrefix("2026-01-10 09:00:00") == true, "\(result.rows)")
            #expect(result.rows.last?.values[4] == "329.99")
            let none = try await console.runSQL("SELECT id FROM customers WHERE country IS NULL AND id > 100")
            #expect(none.isEmpty)
            do {
                _ = try await console.runSQL("SELECT * FORM customers")
                Issue.record("A syntax error should fail")
            } catch DatabaseError.statementFailed(let message) {
                #expect(message.localizedCaseInsensitiveContains("syntax"), "\(message)")
            }
            do {
                _ = try await console.runSQL("DELETE FROM customers WHERE id = 1")
                Issue.record("query_reader shouldn't be able to delete")
            } catch DatabaseError.statementFailed(let message) {
                #expect(message.localizedCaseInsensitiveContains("denied"), "\(message)")
            }
            await console.close()
        } catch {
            await console.close()
            throw error
        }
    }

    static var rowEditCases: [Case] { activeCases.filter { [.postgreSQL, .mySQL, .mariaDB].contains($0.engine) } }

    @Test(.enabled(if: !rowEditCases.isEmpty), arguments: rowEditCases)
    func rowEditsUpdateOneRowByPrimaryKey(_ testCase: Case) async throws {
        let factory = DefaultDatabaseClientFactory()
        let writerValues = testCase.values.merging([.username: "query_writer", .password: "WriterPass1"]) { $1 }
        let writer = try #require(try factory.makeClient(for: ConnectionDraft(engine: testCase.engine, values: writerValues)) as? any RowUpdating)
        let reader = try #require(try client(testCase) as? any RowUpdating)
        defer { Task { await writer.close(); await reader.close() } }

        let columns = try await writer.columns(of: testCase.customers)
        let idRule = FilterRule(column: "id", filterOperator: .equals, value: "7")
        func row() async throws -> [String?] {
            try #require(try await writer.rows(of: testCase.customers, columns: columns, rules: [idRule], limit: 2).rows.first).values
        }
        let key = try await writer.primaryKey(of: testCase.customers)
        #expect(key == ["id"])
        let country = try #require(columns.firstIndex { $0.name == "country" })

        let original = try await row()
        var edited = original
        edited[country] = "MX"
        try await writer.update(RowChange(object: testCase.customers, columns: columns, original: original, values: edited, keyColumns: key))
        #expect(try await row()[country] == "MX")
        // Put it back (the seed has NULL here).
        try await writer.update(RowChange(object: testCase.customers, columns: columns, original: edited, values: original, keyColumns: key))
        #expect(try await row() == original)

        do {
            try await reader.update(RowChange(object: testCase.customers, columns: columns, original: original, values: edited, keyColumns: key))
            Issue.record("query_reader shouldn't be able to update")
        } catch DatabaseError.statementFailed(let message) {
            #expect(message.localizedCaseInsensitiveContains("denied"), "\(message)")
        }
    }

    @Test(.enabled(if: enabled.contains(DatabaseEngine.redis.rawValue)))
    func redisKeysAndPatternFilters() async throws {
        let client = try DefaultDatabaseClientFactory().makeClient(for: ConnectionDraft(
            engine: .redis, values: Self.reader.merging([.port: "16379", .database: "0"]) { $1 }
        ))
        let objects = try await client.listObjects()
        guard objects.map(\.name) == ["db0", "db1"] else {
            await client.close()
            Issue.record("objects: \(objects.map(\.name))")
            return
        }
        let db0 = objects[0]
        let columns = try await client.columns(of: db0)
        let customers = try await client.rows(
            of: db0, columns: columns, rules: [FilterRule(column: "key", filterOperator: .beginsWith, value: "customer:")], limit: 100
        )
        #expect(customers.rows.count == 12)
        #expect(customers.rows.allSatisfy { $0.values[1] == "hash" })
        let sets = try await client.rows(of: db0, columns: columns, rules: [FilterRule(column: "type", filterOperator: .equals, value: "set")], limit: 100)
        #expect(sets.rows.map { $0.values[0] } == ["countries"])
        let db1 = try await client.rows(of: objects[1], columns: columns, rules: [], limit: 100)
        #expect(db1.rows.first?.values[3] == "hello from db1")
        await client.close()
    }
}

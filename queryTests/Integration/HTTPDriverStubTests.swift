import Foundation
import Testing
@testable import query

/// Engines with no local server (Cloudflare D1, Snowflake), driven through a stubbed transport
/// with fixtures shaped like the real APIs' responses.
@Suite("HTTP drivers (stubbed transport)", .tags(.integration))
struct HTTPDriverStubTests {
    private let customers = DatabaseObject(schema: "main", name: "customers", kind: .table)

    @Test func cloudflareD1ListsObjectsAndBindsParameters() async throws {
        let host = "d1-\(UUID().uuidString.prefix(8)).test"
        StubURLProtocol.register(host: host) { _, body in
            let sql = (try? JSONText.object(body))?["sql"] as? String ?? ""
            return (200, FixtureFile.data(sql.contains("sqlite_schema") ? "d1-raw-objects" : "d1-raw-rows"))
        }
        let client = CloudflareD1DatabaseClient(
            accountID: "acc", databaseID: "db", token: "tok", api: StubURLProtocol.client(),
            baseURL: URL(string: "https://\(host)/client/v4")
        )
        let objects = try await client.listObjects()
        #expect(objects.map(\.name) == ["customers", "orderLineSummary", "orders"])
        #expect(objects[1].kind == .view)

        let columns = [ColumnInfo(name: "id", dataType: "INTEGER"), ColumnInfo(name: "email", dataType: "TEXT"), ColumnInfo(name: "country", dataType: "TEXT")]
        let result = try await client.rows(of: customers, columns: columns, rules: [FilterRule(column: "email", filterOperator: .contains, value: "ada")], limit: 10)
        #expect(result.rows.map(\.values) == [["1", "ada.lovelace@example.com", "GB"], ["7", "dennis.ritchie@example.com", nil], ["12", "frances.allen@mail.test", "US"]])

        let (request, body) = try #require(StubURLProtocol.requests(for: host).last)
        #expect(request.url?.path == "/client/v4/accounts/acc/d1/database/db/raw")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
        let sent = try JSONText.object(body)
        #expect(sent["params"] as? [String] == ["%ada%"])
        #expect((sent["sql"] as? String)?.contains("LIKE LOWER(?1)") == true)
    }

    @Test func cloudflareD1ErrorsMapSilently() async {
        let host = "d1-\(UUID().uuidString.prefix(8)).test"
        StubURLProtocol.register(host: host) { _, _ in (403, Data(#"{"success":false,"errors":[{"code":10000,"message":"Authentication error"}]}"#.utf8)) }
        let client = CloudflareD1DatabaseClient(accountID: "a", databaseID: "d", token: "bad", api: StubURLProtocol.client(), baseURL: URL(string: "https://\(host)"))
        await #expect(throws: DatabaseError.connectionFailed) { try await client.listObjects() }
    }

    @Test func snowflakeSendsTypedBindingsAndReadsRows() async throws {
        let account = "acct\(UUID().uuidString.prefix(6).lowercased())"
        let host = "\(account).snowflakecomputing.com"
        StubURLProtocol.register(host: host) { _, _ in (200, FixtureFile.data("snowflake-statement")) }
        let client = SnowflakeDatabaseClient(
            account: account, token: "pat-token", database: "QUERY_TEST", schema: "PUBLIC", warehouse: "WH", role: "READER",
            api: StubURLProtocol.client()
        )
        let columns = [ColumnInfo(name: "ID", dataType: "NUMBER(38,0)"), ColumnInfo(name: "COUNTRY", dataType: "TEXT")]
        let object = DatabaseObject(schema: "PUBLIC", name: "CUSTOMERS", kind: .table)
        let result = try await client.rows(of: object, columns: columns, rules: [FilterRule(column: "ID", filterOperator: .greaterThan, value: "0")], limit: 5)
        #expect(result.rows.map(\.values) == [["1", "GB"], ["7", nil]])

        let (request, body) = try #require(StubURLProtocol.requests(for: host).first)
        #expect(request.url?.path == "/api/v2/statements")
        #expect(request.value(forHTTPHeaderField: "X-Snowflake-Authorization-Token-Type") == "PROGRAMMATIC_ACCESS_TOKEN")
        let sent = try JSONText.object(body)
        #expect(sent["warehouse"] as? String == "WH")
        #expect((sent["bindings"] as? [String: [String: String]])?["1"] == ["type": "TEXT", "value": "0"])
        #expect((sent["statement"] as? String)?.contains(#""ID" > CAST(? AS NUMBER(38,0))"#) == true)
    }

    @Test func snowflakePollsAsynchronousStatements() async throws {
        let account = "acct\(UUID().uuidString.prefix(6).lowercased())"
        let host = "\(account).snowflakecomputing.com"
        StubURLProtocol.register(host: host) { request, _ in
            request.httpMethod == "POST" ? (202, FixtureFile.data("snowflake-running")) : (200, FixtureFile.data("snowflake-statement"))
        }
        var client = SnowflakeDatabaseClient(account: account, token: "t", database: nil, schema: nil, warehouse: nil, role: nil, api: StubURLProtocol.client())
        client.pollInterval = .zero
        let rows = try await client.execute(SQLStatement(sql: "SELECT 1"))
        #expect(rows.count == 2)
        let requests = StubURLProtocol.requests(for: host)
        #expect(requests.count == 2)
        #expect(requests.last?.0.url?.path == "/api/v2/statements/01b2c3d4-0000-0000-0000-000000000002")
    }
}

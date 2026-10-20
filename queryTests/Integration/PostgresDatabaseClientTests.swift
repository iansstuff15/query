import Foundation
import Testing
@testable import query

/// Driver error mapping without any server.
@Suite("Driver error mapping", .tags(.integration))
struct PostgresDatabaseClientTests {
    private let closedPort = ServerEndpoint(host: "127.0.0.1", port: 1, username: "x", password: "x", database: "x", tlsMode: .disable)

    @Test func factoryRejectsMissingConfiguration() {
        #expect(throws: DatabaseError.missingConfiguration) {
            try DefaultDatabaseClientFactory().makeClient(for: ConnectionDraft(engine: .postgreSQL))
        }
        #expect(throws: DatabaseError.missingConfiguration) {
            try DefaultDatabaseClientFactory().makeClient(for: ConnectionDraft(engine: .cloudflareD1, values: [.accountID: "a"]))
        }
    }

    @Test func unreachablePostgresThrowsConnectionFailed() async {
        let client = PostgresDatabaseClient(endpoint: closedPort, flavor: .postgres)
        await #expect(throws: DatabaseError.connectionFailed) { try await client.listObjects() }
    }

    @Test func unreachableMySQLThrowsConnectionFailed() async {
        await #expect(throws: DatabaseError.connectionFailed) { try await MySQLDatabaseClient(endpoint: closedPort).listObjects() }
    }

    @Test func unreachableSQLServerThrowsConnectionFailed() async {
        await #expect(throws: DatabaseError.connectionFailed) { try await SQLServerDatabaseClient(endpoint: closedPort).listObjects() }
    }

    @Test func unreachableRedisThrowsConnectionFailed() async {
        await #expect(throws: DatabaseError.connectionFailed) { try await RedisDatabaseClient(endpoint: closedPort).listObjects() }
    }

    @Test func missingSQLiteFileThrowsConnectionFailed() async {
        let client = SQLiteDatabaseClient(fileURL: FileManager.default.temporaryDirectory.appending(path: "missing-\(UUID()).sqlite"))
        await #expect(throws: DatabaseError.connectionFailed) { try await client.listObjects() }
    }
}

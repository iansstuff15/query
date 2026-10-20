import Foundation

/// Returns stub clients for every engine (previews and UI tests).
nonisolated struct StubDatabaseClientFactory: DatabaseClientFactory {
    var scenario: StubScenario = .sample
    var delay: Duration = .zero

    func makeClient(for draft: ConnectionDraft) throws -> any DatabaseClient {
        StubDatabaseClient(scenario: scenario, delay: delay)
    }
}

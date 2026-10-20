import CassandraClient
import Foundation
import NIOPosix

/// The DataStax C++ driver behind the Cassandra client loads (no network traffic).
nonisolated struct CassandraDriverCheck: StartupCheck {
    var id: StartupCheckID { .cassandraDriver }

    func run() async -> StartupCheckOutcome {
        let configuration = CassandraClient.Configuration(
            contactPointsProvider: { callback in callback(.success(["127.0.0.1"])) },
            port: 9_042,
            protocolVersion: .v4
        )
        let client = CassandraClient(eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton), configuration: configuration)
        do {
            try await client.shutdownAsync()
            return .passed(detail: nil)
        } catch {
            return .degraded(reason: String(describing: error))
        }
    }
}

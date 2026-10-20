import Foundation

/// Builds the driver for a connection draft.
nonisolated protocol DatabaseClientFactory: Sendable {
    func makeClient(for draft: ConnectionDraft) throws -> any DatabaseClient
}

import Foundation
import Observation

/// Open connections by id, so windows other than the workspace (Users & Permissions) can use a
/// workspace's connection. Workspaces register on connect and unregister on disconnect.
@MainActor
@Observable
final class SessionRegistry {
    private(set) var sessions: [UUID: ConnectionSession] = [:]

    /// Nonisolated so it can serve as a default argument.
    nonisolated init() {}

    func register(_ session: ConnectionSession) {
        sessions[session.id] = session
    }

    func unregister(_ id: UUID) {
        sessions[id] = nil
    }

    func session(_ id: UUID) -> ConnectionSession? {
        sessions[id]
    }
}

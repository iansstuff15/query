import Foundation
import Observation

/// Per-window state: the welcome screen until a connection opens, then its workspace.
@MainActor
@Observable
final class SessionViewModel {
    private(set) var session: ConnectionSession?

    func open(_ session: ConnectionSession) {
        self.session = session
    }

    func disconnect() async {
        let closing = session
        session = nil
        await closing?.client.close()
    }
}

import Foundation
import Network

/// A network path is available (local databases still work without one).
nonisolated struct NetworkCheck: StartupCheck {
    var timeout: Duration = .seconds(2)
    var id: StartupCheckID { .network }

    func run() async -> StartupCheckOutcome {
        let monitor = NWPathMonitor()
        defer { monitor.cancel() }
        let status: NWPath.Status? = await withTaskGroup(of: Optional<NWPath.Status>.self) { group in
            group.addTask {
                for await path in monitor { return path.status }
                return nil
            }
            group.addTask { [timeout] in
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next()
            group.cancelAll()
            return first.flatMap { $0 }
        }
        switch status {
        case .satisfied: return .passed(detail: nil)
        case .some(let other): return .degraded(reason: "path status \(other)")
        case nil: return .degraded(reason: "no path update within timeout")
        }
    }
}

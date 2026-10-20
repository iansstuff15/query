import Foundation

nonisolated enum StartupCheckOutcome: Hashable, Sendable {
    /// Working; `detail` is a short version or count shown on the splash screen.
    case passed(detail: String?)
    /// Not working. `reason` is logged internally, never shown to the user.
    case degraded(reason: String)

    var isPassed: Bool {
        if case .passed = self { return true }
        return false
    }
}

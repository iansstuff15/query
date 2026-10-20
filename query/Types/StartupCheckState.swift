import Foundation

nonisolated enum StartupCheckState: Hashable, Sendable {
    case pending
    case running
    case finished(StartupCheckOutcome)
}

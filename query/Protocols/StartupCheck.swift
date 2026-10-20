import Foundation

/// One verification run while the splash screen is visible.
nonisolated protocol StartupCheck: Sendable {
    var id: StartupCheckID { get }
    func run() async -> StartupCheckOutcome
}

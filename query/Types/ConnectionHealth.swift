import Foundation

/// Whether a saved connection answered the welcome screen's background check.
nonisolated enum ConnectionHealth: Equatable, Sendable {
    case unknown
    case checking
    case reachable
    case unreachable

    /// Unreachable connections can't be opened from the list; edit them instead.
    var canOpen: Bool { self != .unreachable }
}

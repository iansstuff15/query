import Foundation

/// A Save (row, user or permissions), from idle to saved or failed.
nonisolated enum SaveState: Equatable, Sendable {
    case idle
    case saving
    case saved
    /// The server's message, when it sent one.
    case failed(String?)
}

import Foundation

/// The Row tab's Save, from idle to saved or failed.
nonisolated enum RowSaveState: Equatable, Sendable {
    case idle
    case saving
    case saved
    /// The server's message, when it sent one.
    case failed(String?)
}

import Foundation

/// Tabs of the workspace's right panel.
nonisolated enum SQLConsoleTab: String, CaseIterable, Identifiable, Sendable {
    case editor
    case history
    /// The selected table row's fields.
    case row

    var id: String { rawValue }
}

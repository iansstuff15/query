import Foundation

/// A tab in the center panel's tab bar, like an Xcode editor tab.
nonisolated enum WorkspaceTab: Hashable, Identifiable, Sendable {
    /// A table, view or other object's rows.
    case object(DatabaseObject.ID)
    /// One distinct SQL statement's latest result (keyed by `SQLEditorStatement.key(for:)`).
    case query(String)

    var id: String {
        switch self {
        case .object(let id): "object.\(id)"
        case .query(let key): "query.\(key)"
        }
    }
}

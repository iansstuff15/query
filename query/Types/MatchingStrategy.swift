import Foundation

/// How the sidebar and Open Anything match typed text against object names.
nonisolated enum MatchingStrategy: String, CaseIterable, Identifiable, Hashable, Sendable {
    case fuzzy
    case contains
    case prefix

    var id: String { rawValue }
}

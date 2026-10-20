import Foundation

/// One `## [version] - date` release from CHANGELOG.md.
nonisolated struct ChangelogRelease: Identifiable, Hashable, Sendable {
    struct Section: Identifiable, Hashable, Sendable {
        let category: ChangelogCategory
        let items: [String]

        var id: ChangelogCategory { category }
    }

    let version: String
    /// The date as written (`2026-10-21`), if any.
    let date: String?
    let sections: [Section]

    var id: String { version }

    /// "Unreleased" collects changes not shipped yet.
    var isUnreleased: Bool { version.caseInsensitiveCompare("Unreleased") == .orderedSame }

    var itemCount: Int { sections.reduce(0) { $0 + $1.items.count } }
}

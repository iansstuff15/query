import Foundation

/// A group of changes within a release, from a `### Heading` in CHANGELOG.md.
nonisolated enum ChangelogCategory: Hashable, Sendable {
    case newFeatures
    case uiChanges
    case improvements
    case bugFixes
    case security
    case removed
    /// Any other heading, shown as written.
    case other(String)

    /// Recognizes Keep a Changelog headings (Added, Changed, Fixed…) and friendlier ones. A
    /// leading emoji (`✨ New Features`) is ignored: the app shows its own icon per category.
    init(heading: String) {
        let name = String(heading.drop { !$0.isLetter && !$0.isNumber }).trimmingCharacters(in: .whitespaces)
        let key = name.lowercased()
        switch key {
        case "added", "new", "features", "new features", "feature": self = .newFeatures
        case "ui", "ui changes", "ux", "ui/ux", "design", "interface", "visual changes": self = .uiChanges
        case "changed", "improvements", "improved", "enhancements", "performance": self = .improvements
        case "fixed", "fixes", "bug fixes", "bugfixes", "bugs": self = .bugFixes
        case "security": self = .security
        case "removed", "deprecated": self = .removed
        default: self = .other(name.isEmpty ? heading.trimmingCharacters(in: .whitespaces) : name)
        }
    }

    var systemImage: String {
        switch self {
        case .newFeatures: "sparkles"
        case .uiChanges: "paintbrush.pointed"
        case .improvements: "arrow.up.circle"
        case .bugFixes: "ladybug"
        case .security: "lock.shield"
        case .removed: "minus.circle"
        case .other: "list.bullet"
        }
    }
}

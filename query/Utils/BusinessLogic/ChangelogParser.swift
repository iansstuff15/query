import Foundation

/// Reads a Keep a Changelog–style Markdown file: `## [1.2.0] - 2026-10-21` starts a release,
/// `### Heading` a category, and `- item` (or `* item`) a change; indented lines continue the
/// previous item. Anything else (title, intro text) is ignored.
nonisolated enum ChangelogParser {
    static func releases(from markdown: String) -> [ChangelogRelease] {
        var releases: [ChangelogRelease] = []
        var version: String?
        var date: String?
        var sections: [ChangelogRelease.Section] = []
        var category: ChangelogCategory?
        var items: [String] = []

        func closeSection() {
            if let category, !items.isEmpty { sections.append(.init(category: category, items: items)) }
            category = nil
            items = []
        }
        func closeRelease() {
            closeSection()
            if let version, !sections.isEmpty { releases.append(ChangelogRelease(version: version, date: date, sections: sections)) }
            version = nil
            date = nil
            sections = []
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                closeRelease()
                (version, date) = releaseHeading(String(line.dropFirst(3)))
            } else if line.hasPrefix("### "), version != nil {
                closeSection()
                category = ChangelogCategory(heading: String(line.dropFirst(4)))
            } else if line.hasPrefix("- ") || line.hasPrefix("* "), category != nil {
                items.append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            } else if !line.isEmpty, rawLine.first?.isWhitespace == true, category != nil, let last = items.popLast() {
                items.append(last + " " + line)
            }
        }
        closeRelease()
        return releases
    }

    /// `[1.2.0] - 2026-10-21`, `1.2.0 (2026-10-21)` or just `1.2.0`.
    private static func releaseHeading(_ text: String) -> (String, String?) {
        let parts = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let first = parts.first else { return (text, nil) }
        let version = first.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let date = parts.dropFirst().first { $0.first?.isNumber == true || $0.first == "(" }?
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        return (version, date)
    }
}

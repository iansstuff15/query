import Foundation

/// Fixed release notes for previews and tests.
nonisolated struct StaticChangelogProvider: ChangelogProviding {
    var markdown: String

    func releases() throws -> [ChangelogRelease] {
        ChangelogParser.releases(from: markdown)
    }
}

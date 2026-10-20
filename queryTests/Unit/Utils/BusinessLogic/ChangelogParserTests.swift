import Foundation
import Testing
@testable import query

@Suite("ChangelogParser")
struct ChangelogParserTests {
    private let sample = """
    # Changelog

    Intro text that isn't a release.

    ## [Unreleased]

    ## [1.2.0] - 2026-10-21
    ### New Features
    - **Tabs** for open tables
      that wrap onto a second line.
    * Starred bullets work too.
    ### UI Changes
    - A jump bar.
    ### Fixed
    - A `DATETIME` bug.
    ### Developer Tools
    - Docker databases.

    ## 1.1.0 (2026-10-20)
    ### Added
    - First feature.
    """

    @Test func readsReleasesNewestFirstAndSkipsEmptyOnes() {
        let releases = ChangelogParser.releases(from: sample)
        #expect(releases.map(\.version) == ["1.2.0", "1.1.0"])
        #expect(releases.map(\.date) == ["2026-10-21", "2026-10-20"])
    }

    @Test func groupsItemsByCategory() throws {
        let release = try #require(ChangelogParser.releases(from: sample).first)
        #expect(release.sections.map(\.category) == [.newFeatures, .uiChanges, .bugFixes, .other("Developer Tools")])
        #expect(release.sections[0].items == ["**Tabs** for open tables that wrap onto a second line.", "Starred bullets work too."])
        #expect(release.itemCount == 5)
    }

    @Test(arguments: [
        ("Added", ChangelogCategory.newFeatures), ("New Features", .newFeatures), ("UI Changes", .uiChanges), ("Design", .uiChanges),
        ("Changed", .improvements), ("Bug Fixes", .bugFixes), ("bugfixes", .bugFixes), ("Fixed", .bugFixes),
        ("Security", .security), ("Deprecated", .removed), ("Docs", .other("Docs")),
        ("✨ New Features", .newFeatures), ("🎨 UI Changes", .uiChanges), ("⚡️ Improvements", .improvements),
        ("🐛 Bug Fixes", .bugFixes), ("🔒 Security", .security), ("🗑️ Removed", .removed), ("🛠️ Developer Tools", .other("Developer Tools")),
    ])
    func recognizesHeadings(heading: String, category: ChangelogCategory) {
        #expect(ChangelogCategory(heading: heading) == category)
    }

    @Test func emptyOrUnstructuredTextHasNoReleases() {
        #expect(ChangelogParser.releases(from: "").isEmpty)
        #expect(ChangelogParser.releases(from: "- loose bullet\n### Orphan heading\n- item").isEmpty)
    }

    @Test func theBundledChangelogParses() throws {
        let url = try #require(Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"))
        let releases = ChangelogParser.releases(from: try String(contentsOf: url, encoding: .utf8))
        #expect(!releases.isEmpty)
        #expect(releases.allSatisfy { $0.date != nil && $0.itemCount > 0 })
        let categories = Set(releases.flatMap { $0.sections.map(\.category) })
        #expect(categories.isSuperset(of: [.newFeatures, .uiChanges, .bugFixes]))
        // Every heading uses the emoji convention in Claude.md, so none fall through to "other"
        // except Developer Tools.
        #expect(categories.subtracting([.newFeatures, .uiChanges, .improvements, .bugFixes, .security, .removed]) == [.other("Developer Tools")])
        let text = try String(contentsOf: url, encoding: .utf8)
        let headings = text.components(separatedBy: .newlines).filter { $0.hasPrefix("### ") }
        #expect(headings.allSatisfy { $0.dropFirst(4).first.map { !$0.isLetter } == true }, "every category heading starts with an emoji")
    }
}

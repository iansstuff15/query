import Testing
@testable import query

private struct BrokenChangelog: ChangelogProviding {
    func releases() throws -> [ChangelogRelease] { throw MockError() }
}

@MainActor
@Suite("WhatsNewViewModel")
struct WhatsNewViewModelTests {
    private let markdown = """
    ## [Unreleased]
    ### Added
    - Coming soon.
    ## [2.0.0] - 2026-10-21
    ### Bug Fixes
    - A fix.
    ## [1.0.0] - 2026-10-01
    ### Added
    - First.
    """

    @Test func loadsAndShowsTheNewestShippedRelease() async {
        let model = WhatsNewViewModel(provider: StaticChangelogProvider(markdown: markdown))
        await model.load()
        #expect(model.releases.map(\.version) == ["Unreleased", "2.0.0", "1.0.0"])
        #expect(model.latestVersion == "2.0.0")
        #expect(model.selectedRelease?.version == "2.0.0")
        model.selectedVersion = "1.0.0"
        #expect(model.selectedRelease?.sections.first?.items == ["First."])
    }

    @Test func aMissingChangelogIsAQuietFailure() async {
        let model = WhatsNewViewModel(provider: BrokenChangelog())
        await model.load()
        guard case .failed = model.state else {
            Issue.record("Expected failed state")
            return
        }
        #expect(model.selectedRelease == nil)
        #expect(model.latestVersion == nil)
    }

    @Test(arguments: [
        ("2.0.0", "1.0.0", true),   // updated
        ("2.0.0", "2.0.0", false),  // already seen
        ("2.0.0", "", false),       // fresh install
    ])
    func opensOnceAfterAnUpdate(latest: String, lastSeen: String, opens: Bool) {
        #expect(WhatsNewViewModel.shouldOpenAutomatically(latest: latest, lastSeen: lastSeen) == opens)
    }

    @Test func alwaysOpensWhenTheFlagIsOn() {
        #expect(WhatsNewViewModel.shouldOpenAutomatically(latest: "2.0.0", lastSeen: "2.0.0", always: true))
        #expect(WhatsNewViewModel.shouldOpenAutomatically(latest: "2.0.0", lastSeen: "", always: true))
        #expect(!WhatsNewViewModel.shouldOpenAutomatically(latest: nil, lastSeen: "", always: true))
    }

    @Test func noReleasesNeverOpens() {
        #expect(!WhatsNewViewModel.shouldOpenAutomatically(latest: nil, lastSeen: "1.0.0"))
    }
}

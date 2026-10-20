import Foundation
import Observation
import os

/// The What's New window: releases from CHANGELOG.md and which one is shown.
@MainActor
@Observable
final class WhatsNewViewModel {
    private(set) var state: LoadState<[ChangelogRelease]> = .idle
    var selectedVersion: String?

    private let provider: any ChangelogProviding

    init(provider: any ChangelogProviding) {
        self.provider = provider
    }

    var releases: [ChangelogRelease] { state.value ?? [] }

    var selectedRelease: ChangelogRelease? {
        releases.first { $0.version == selectedVersion } ?? releases.first
    }

    /// The newest shipped release (an "Unreleased" section doesn't count).
    var latestVersion: String? {
        releases.first { !$0.isUnreleased }?.version
    }

    func load() async {
        state = .loading
        let provider = provider
        do {
            let releases = try await Task.detached { try provider.releases() }.value
            state = .loaded(releases)
            selectedVersion = latestVersion ?? releases.first?.version
        } catch {
            AppLog.startup.error("Reading the changelog failed: \(String(describing: error), privacy: .private)")
            state = .failed(error)
        }
    }

    /// Opens by itself once after an update, or at every launch when `always` is set
    /// (`ALWAYS_SHOW_CHANGELOG`). A fresh install skips it otherwise; the window is always
    /// available from Help ▸ What's New.
    static func shouldOpenAutomatically(latest: String?, lastSeen: String, always: Bool = false) -> Bool {
        guard let latest else { return false }
        if always { return true }
        guard !lastSeen.isEmpty else { return false }
        return latest != lastSeen
    }

    /// Set once What's New has opened by itself, so a second window doesn't open it again.
    static var hasOpenedThisLaunch = false
}

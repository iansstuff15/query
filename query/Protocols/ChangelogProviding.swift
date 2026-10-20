import Foundation

/// Release notes for the What's New window, newest first.
nonisolated protocol ChangelogProviding: Sendable {
    func releases() throws -> [ChangelogRelease]
}

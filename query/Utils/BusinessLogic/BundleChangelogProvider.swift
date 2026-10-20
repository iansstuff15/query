import Foundation

/// Release notes from the CHANGELOG.md copied into the app bundle (`query/Resources`).
nonisolated struct BundleChangelogProvider: ChangelogProviding {
    var bundle: Bundle = .main

    func releases() throws -> [ChangelogRelease] {
        guard let url = bundle.url(forResource: "CHANGELOG", withExtension: "md") else { throw CocoaError(.fileNoSuchFile) }
        return ChangelogParser.releases(from: try String(contentsOf: url, encoding: .utf8))
    }
}

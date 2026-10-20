import Foundation
import Observation

/// ⌘P palette: ranks cached objects locally as the user types and tracks keyboard highlight.
@MainActor
@Observable
final class OpenAnythingViewModel {
    var query = "" {
        didSet {
            guard oldValue != query else { return }
            recompute()
        }
    }
    private(set) var results: [SearchMatch] = []
    private(set) var highlightedIndex = 0

    private let objects: [DatabaseObject]
    private let matcher: TextMatcher
    private let resultLimit: Int

    init(objects: [DatabaseObject], matcher: TextMatcher, resultLimit: Int = AppConfig.paletteResultLimit) {
        self.objects = objects
        self.matcher = matcher
        self.resultLimit = resultLimit
        recompute()
    }

    var highlightedObject: DatabaseObject? {
        results.indices.contains(highlightedIndex) ? results[highlightedIndex].object : nil
    }

    func moveHighlight(by delta: Int) {
        guard !results.isEmpty else { return }
        highlightedIndex = min(max(highlightedIndex + delta, 0), results.count - 1)
    }

    func highlight(_ index: Int) {
        guard results.indices.contains(index) else { return }
        highlightedIndex = index
    }

    private func recompute() {
        results = Array(ObjectSearch.rank(objects, query: query, matcher: matcher).prefix(resultLimit))
        highlightedIndex = 0
    }
}

import Testing
@testable import query

@MainActor
@Suite("OpenAnythingViewModel")
struct OpenAnythingViewModelTests {
    private func makeModel(limit: Int = 50) -> OpenAnythingViewModel {
        OpenAnythingViewModel(objects: SampleCatalog.objects, matcher: TextMatcher(strategy: .fuzzy), resultLimit: limit)
    }

    @Test func startsWithEveryObjectHighlightingFirst() {
        let model = makeModel()
        #expect(model.results.count == SampleCatalog.objects.count)
        #expect(model.highlightedObject == SampleCatalog.objects.first)
    }

    @Test func typingRanksBestMatchFirst() {
        let model = makeModel()
        model.query = "oi"
        #expect(model.highlightedObject?.name == "order_items")
    }

    @Test func arrowKeysMoveAndClamp() {
        let model = makeModel()
        model.query = "ord"
        let count = model.results.count
        model.moveHighlight(by: 1)
        #expect(model.highlightedIndex == 1)
        model.moveHighlight(by: 100)
        #expect(model.highlightedIndex == count - 1)
        model.moveHighlight(by: -100)
        #expect(model.highlightedIndex == 0)
    }

    @Test func newQueryResetsHighlight() {
        let model = makeModel()
        model.moveHighlight(by: 2)
        model.query = "o"
        #expect(model.highlightedIndex == 0)
    }

    @Test func noMatchesHasNoHighlight() {
        let model = makeModel()
        model.query = "zzz"
        model.moveHighlight(by: 1)
        #expect(model.results.isEmpty)
        #expect(model.highlightedObject == nil)
    }

    @Test func respectsResultLimitAndIgnoresInvalidHighlight() {
        let model = makeModel(limit: 3)
        #expect(model.results.count == 3)
        model.highlight(2)
        #expect(model.highlightedIndex == 2)
        model.highlight(7)
        #expect(model.highlightedIndex == 2)
    }
}

import Testing
@testable import query

@Suite("ObjectSearch")
struct ObjectSearchTests {
    private let matcher = TextMatcher(strategy: .fuzzy)

    @Test func emptyQueryKeepsCatalogOrder() {
        let ranked = ObjectSearch.rank(SampleCatalog.objects, query: "", matcher: matcher)
        #expect(ranked.map(\.object) == SampleCatalog.objects)
        #expect(ranked.allSatisfy { $0.nameOffsets.isEmpty })
    }

    @Test func rankPutsBestMatchFirst() {
        let ranked = ObjectSearch.rank(SampleCatalog.objects, query: "oi", matcher: matcher)
        #expect(ranked.first?.object.name == "order_items")
        #expect(ranked.first?.nameOffsets == [0, 6])
    }

    @Test func dottedQueryRestrictsSchema() {
        let ranked = ObjectSearch.rank(SampleCatalog.objects, query: "sales.ord", matcher: matcher)
        #expect(ranked.map(\.object.id) == ["sales.orderLineSummary"])
    }

    @Test func dottedQueryWithEmptyNameListsSchema() {
        let ranked = ObjectSearch.rank(SampleCatalog.objects, query: "analytics.", matcher: matcher)
        #expect(Set(ranked.map(\.object.schema)) == ["analytics"])
        #expect(ranked.count == 2)
    }

    @Test func sectionsGroupBySchemaInCatalogOrder() {
        let sections = ObjectSearch.sections(SampleCatalog.objects, query: "", matcher: matcher)
        #expect(sections.map(\.schema) == ["analytics", "public", "sales"])
        #expect(sections[1].objects.count == 5)
    }

    @Test func sectionsFilterAndDropEmptySchemas() {
        let sections = ObjectSearch.sections(SampleCatalog.objects, query: "cust", matcher: matcher)
        #expect(sections.map(\.schema) == ["public"])
        #expect(sections.first?.objects.map(\.name) == ["customers"])
    }

    @Test func sectionsEmptyWhenNothingMatches() {
        #expect(ObjectSearch.sections(SampleCatalog.objects, query: "zzz", matcher: matcher).isEmpty)
    }
}

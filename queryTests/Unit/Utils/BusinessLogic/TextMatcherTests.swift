import Testing
@testable import query

@Suite("TextMatcher")
struct TextMatcherTests {
    private let fuzzy = TextMatcher(strategy: .fuzzy)

    @Test func fuzzyMatchesWordBoundaries() throws {
        let match = try #require(fuzzy.match("oi", in: "order_items"))
        #expect(match.offsets == [0, 6])
    }

    @Test func fuzzyMatchesCamelCaseBoundaries() throws {
        let match = try #require(fuzzy.match("ls", in: "orderLineSummary"))
        #expect(match.offsets == [5, 9])
    }

    @Test func fuzzyIsCaseInsensitive() {
        #expect(fuzzy.match("OI", in: "order_items") != nil)
    }

    @Test func fuzzyRequiresCharactersInOrder() {
        #expect(fuzzy.match("so", in: "orders") == nil)
    }

    @Test func fuzzyFallsBackWhenBoundaryWouldStrandTheRestOfTheQuery() throws {
        let match = try #require(fuzzy.match("ab", in: "xab_a"))
        #expect(match.offsets == [1, 2])
    }

    @Test func fuzzyRanksPrefixAndShorterNamesFirst() throws {
        let names = ["recent_orders", "orderLineSummary", "order_items", "orders"]
        let ranked = names
            .compactMap { name in fuzzy.match("ord", in: name).map { (name, $0.score) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        #expect(ranked == ["orders", "order_items", "orderLineSummary", "recent_orders"])
    }

    @Test func exactMatchOutranksPrefix() throws {
        let exact = try #require(fuzzy.match("orders", in: "orders"))
        let prefix = try #require(fuzzy.match("orders", in: "orders_archive"))
        #expect(exact.score > prefix.score)
    }

    @Test func emptyQueryMatchesEverything() {
        #expect(fuzzy.match("  ", in: "orders") == TextMatch(score: 0, offsets: []))
    }

    @Test func queryLongerThanCandidateFails() {
        #expect(fuzzy.match("orders_long", in: "orders") == nil)
    }

    @Test func containsMatchesContiguousSubstring() throws {
        let matcher = TextMatcher(strategy: .contains)
        let match = try #require(matcher.match("ITEM", in: "order_items"))
        #expect(match.offsets == [6, 7, 8, 9])
        #expect(matcher.match("oi", in: "order_items") == nil)
    }

    @Test func prefixMatchesOnlyAtStart() throws {
        let matcher = TextMatcher(strategy: .prefix)
        let match = try #require(matcher.match("ord", in: "orders"))
        #expect(match.offsets == [0, 1, 2])
        #expect(matcher.match("ord", in: "recent_orders") == nil)
    }
}

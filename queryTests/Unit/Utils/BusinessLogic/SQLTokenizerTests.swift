import Foundation
import Testing
@testable import query

@Suite("SQLTokenizer")
struct SQLTokenizerTests {
    private let tables: Set<String> = ["customers", "orders", "order"]

    /// The text of each token with its kind.
    private func spans(_ sql: String) -> [(String, SQLToken.Kind)] {
        SQLTokenizer.tokens(in: sql, tables: tables).map { ((sql as NSString).substring(with: $0.range), $0.kind) }
    }

    @Test func keywordsAndTablesInAnyCase() {
        let result = spans("select id From Customers c join orders o on o.customer_id = c.id")
        #expect(result.map(\.0) == ["select", "From", "Customers", "join", "orders", "on"])
        #expect(result.map(\.1) == [.keyword, .keyword, .table, .keyword, .table, .keyword])
    }

    @Test func aTableNamedLikeAKeywordIsATableOnlyWhereATableIsExpected() {
        let result = spans("SELECT * FROM order ORDER BY id")
        #expect(result.map(\.1) == [.keyword, .keyword, .table, .keyword, .keyword])
    }

    @Test func stringsWithEscapedQuotesAndUnterminatedStrings() {
        #expect(spans("WHERE name = 'O''Brien' AND x").map(\.0) == ["WHERE", "'O''Brien'", "AND"])
        #expect(spans("SELECT 'unterminated").last?.1 == .string)
    }

    @Test func keywordsInsideStringsAndCommentsArentKeywords() {
        let result = spans("SELECT 'from orders' -- select * from customers\n/* WHERE */ FROM orders")
        #expect(result.map(\.1) == [.keyword, .string, .comment, .comment, .keyword, .table])
    }

    @Test func numbers() {
        #expect(spans("LIMIT 10 OFFSET 2.5e-3 + .5").filter { $0.1 == .number }.map(\.0) == ["10", "2.5e-3", ".5"])
        #expect(spans("SELECT t1.col2").filter { $0.1 == .number }.isEmpty)
    }

    @Test func quotedIdentifiersMatchTables() {
        #expect(spans(#"SELECT * FROM "orders" JOIN `customers`"#).filter { $0.1 == .table }.map(\.0) == [#""orders""#, "`customers`"])
        #expect(spans(#"SELECT "full name" FROM t"#).filter { $0.1 == .table }.isEmpty)
    }

    @Test func rangesAreUTF16ForAppKit() {
        let sql = "SELECT '😀' FROM orders"
        let tokens = SQLTokenizer.tokens(in: sql, tables: tables)
        #expect(tokens.last?.range == (sql as NSString).range(of: "orders"))
    }
}

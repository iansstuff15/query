import Foundation
import Testing
@testable import query

@Suite("SQLCompletion")
struct SQLCompletionTests {
    private let objects = [
        DatabaseObject(schema: "public", name: "customers", kind: .table),
        DatabaseObject(schema: "public", name: "orders", kind: .table),
        DatabaseObject(schema: "public", name: "order_items", kind: .table),
        DatabaseObject(schema: "sales", name: "orderLineSummary", kind: .view),
    ]

    private func suggest(_ sql: String) -> [String] {
        SQLCompletion.suggestions(for: SQLCompletion.context(in: sql, at: (sql as NSString).length), objects: objects)
    }

    @Test func contextFindsThePrefixQualifierAndPreviousWord() {
        let sql = "SELECT * FROM public.ord"
        let context = SQLCompletion.context(in: sql, at: (sql as NSString).length)
        #expect(context == SQLCompletion.Context(prefix: "ord", range: NSRange(location: 21, length: 3), qualifier: "public", previousWord: "from"))
        let middle = SQLCompletion.context(in: "SELEC FROM t", at: 5)
        #expect(middle.prefix == "SELEC")
        #expect(SQLCompletion.context(in: #"FROM "sales".ord"#, at: 16).qualifier == "sales")
    }

    @Test func keywordsFollowTheTypedCase() {
        #expect(suggest("sel").first == "select")
        #expect(suggest("SEL").first == "SELECT")
        #expect(suggest("Sel").first == "SELECT")
    }

    @Test func keywordsComeFirstOutsideATablePosition() {
        let result = suggest("SELECT * FROM customers WHERE id IN (SELECT id FROM orders) OR")
        #expect(result.first == "ORDER")
        #expect(result.contains("orders"))
        #expect(result.firstIndex(of: "ORDER") ?? 0 < result.firstIndex(of: "orders") ?? 0)
    }

    @Test func tablesComeFirstAfterFromAndJoin() {
        let result = suggest("SELECT * FROM or")
        #expect(Array(result.prefix(3)) == ["orders", "order_items", "orderLineSummary"])
        #expect(result.last == "order") // the keyword, after the tables, in the typed case
        #expect(suggest("SELECT * FROM customers c JOIN ").contains("orders"))
    }

    @Test func aSchemaQualifierListsOnlyThatSchemasTables() {
        #expect(suggest("SELECT * FROM sales.") == ["orderLineSummary"])
        #expect(suggest("SELECT * FROM public.order") == ["orders", "order_items"])
        // A table alias isn't a schema.
        #expect(suggest("SELECT c.").isEmpty)
    }

    @Test func nothingForAnExactMatchOrABlankPrefix() {
        #expect(!suggest("SELECT").contains("SELECT"))
        #expect(suggest("SELECT * ").isEmpty)
    }

    @Test func respectsTheLimit() {
        let context = SQLCompletion.context(in: "s", at: 1)
        #expect(SQLCompletion.suggestions(for: context, objects: objects, limit: 3).count == 3)
    }
}

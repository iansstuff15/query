import Foundation
import Testing
@testable import query

@Suite("SQLStatementSplitter")
struct SQLStatementSplitterTests {
    private func sqls(_ text: String) -> [String] {
        SQLStatementSplitter.statements(in: text).map(\.sql)
    }

    @Test func eachLineIsAStatement() {
        #expect(sqls("SELECT 1\nSELECT 2\r\n\n  SELECT 3  ") == ["SELECT 1", "SELECT 2", "SELECT 3"])
    }

    @Test func semicolonsSplitWithinALine() {
        #expect(sqls("SELECT 1; SELECT 2;SELECT 3;") == ["SELECT 1", "SELECT 2", "SELECT 3"])
        #expect(sqls(";;\n;") == [])
    }

    @Test func quotesAndBlockCommentsDontSplit() {
        #expect(sqls("SELECT 'a;b', 'it''s\nfine' FROM t; SELECT 2") == ["SELECT 'a;b', 'it''s\nfine' FROM t", "SELECT 2"])
        #expect(sqls(#"SELECT "x;y" FROM `a;b`"#) == [#"SELECT "x;y" FROM `a;b`"#])
        #expect(sqls("SELECT /* one;\ntwo */ 1") == ["SELECT /* one;\ntwo */ 1"])
    }

    @Test func commentOnlyLinesArentStatements() {
        #expect(sqls("-- heading\nSELECT 1 -- trailing; note\n/* block */\n") == ["SELECT 1 -- trailing; note"])
    }

    @Test func rangesPointAtTheTrimmedStatementInUTF16() {
        let text = "  SELECT '😀';\nSELECT 2"
        let statements = SQLStatementSplitter.statements(in: text)
        #expect(statements.map(\.range) == [(text as NSString).range(of: "SELECT '😀'"), (text as NSString).range(of: "SELECT 2")])
    }

    @Test func statementsForTheCursorOrSelection() {
        let text = "SELECT 1; SELECT 2\nSELECT 3"
        func run(_ range: NSRange) -> [String] { SQLStatementSplitter.statements(in: text, for: range).map(\.sql) }
        #expect(run(NSRange(location: 3, length: 0)) == ["SELECT 1"])
        #expect(run(NSRange(location: 8, length: 0)) == ["SELECT 1"]) // right after the statement, before ;
        #expect(run(NSRange(location: 12, length: 0)) == ["SELECT 2"])
        #expect(run(NSRange(location: 22, length: 0)) == ["SELECT 3"])
        #expect(run(NSRange(location: 5, length: 10)) == ["SELECT 1", "SELECT 2"])
        #expect(run(NSRange(location: 9, length: 0)) == []) // on the ; itself, between statements
    }

    @Test func keysIgnoreSpacing() {
        #expect(SQLEditorStatement.key(for: "SELECT  *\n FROM t") == "SELECT * FROM t")
    }
}

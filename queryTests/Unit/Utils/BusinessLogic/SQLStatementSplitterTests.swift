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

    // MARK: - Statements across lines

    @Test func formattedStatementsStayTogether() {
        let text = """
            SELECT o.id, c.full_name
            FROM orders o JOIN customers c ON c.id = o.customer_id
            WHERE o.total > 10
              AND c.country = 'US'
            ORDER BY o.id;
            SELECT 1
            """
        #expect(sqls(text) == [
            "SELECT o.id, c.full_name\nFROM orders o JOIN customers c ON c.id = o.customer_id\nWHERE o.total > 10\n  AND c.country = 'US'\nORDER BY o.id",
            "SELECT 1",
        ])
    }

    @Test(arguments: [
        ("SELECT a,\n b FROM t", "trailing comma"),
        ("SELECT (\n1)", "open parenthesis"),
        ("SELECT 1 +\n2", "trailing operator"),
        ("SELECT *\nFROM t", "next line starts with FROM"),
        ("SELECT *\n    FROM t", "indented next line"),
        ("INSERT INTO t (a)\nVALUES (1)", "VALUES"),
        ("SELECT * FROM t WHERE\na = 1", "trailing WHERE"),
        ("WITH x AS (SELECT 1)\nSELECT * FROM x", "WITH and its main query"),
        ("SELECT CASE\nWHEN a THEN 1\nELSE 2\nEND FROM t", "CASE"),
    ])
    func continuationLinesJoinTheStatement(text: String, rule: String) {
        #expect(sqls(text).count == 1, "\(rule)")
    }

    @Test func independentLinesStaySeparate() {
        #expect(sqls("SELECT * FROM customers\nSELECT * FROM orders\nDELETE FROM t WHERE id = 1").count == 3)
        #expect(sqls("SELECT a,\n\nb") == ["SELECT a,", "b"]) // a blank line always ends a statement
        #expect(sqls("SELECT 1 -- note, with a comma\nSELECT 2").count == 2) // comments don't count
    }

    /// The SQL test scripts in docker/ (copied into the test fixtures; CI checks they match)
    /// split into one statement per numbered test.
    @Test(arguments: ["postgres-test-queries", "mysql-test-queries"])
    func theDockerTestScriptsSplitIntoTheirNumberedQueries(name: String) throws {
        final class Marker {}
        let url = try #require(Bundle(for: Marker.self).url(forResource: name, withExtension: "sql"))
        let text = try String(contentsOf: url, encoding: .utf8)
        let numbered = text.components(separatedBy: .newlines).filter { $0.range(of: #"^-- \d+\.\d+"#, options: .regularExpression) != nil }
        let statements = SQLStatementSplitter.statements(in: text)
        #expect(statements.count == numbered.count, "\(statements.map(\.sql))")
        let starts: Set<String> = ["select", "insert", "update", "delete", "create", "with", "show"]
        for statement in statements {
            let first = statement.sql.split(whereSeparator: \.isWhitespace).first.map { $0.lowercased() } ?? ""
            #expect(starts.contains(first), "starts with \(first): \(statement.sql)")
        }
    }
}

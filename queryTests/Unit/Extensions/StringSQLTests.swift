import Testing
@testable import query

@Suite("String+SQL")
struct StringSQLTests {
    @Test func quotedIdentifierDoublesQuotes() {
        #expect("users".quotedIdentifier == #""users""#)
        #expect(#"a"b"#.quotedIdentifier == #""a""b""#)
    }

    @Test func escapedLikePatternEscapesWildcards() {
        #expect(#"100%_a\b"#.escapedLikePattern == #"100\%\_a\\b"#)
        #expect("plain".escapedLikePattern == "plain")
    }

    @Test(arguments: [
        ("integer", true),
        ("character varying(255)", true),
        ("timestamp with time zone", true),
        ("numeric(10,2)", true),
        ("text[]", true),
        (#"public."MyType""#, true),
        ("", false),
        ("int; DROP", false),
        ("int -- x", false),
        ("int /* x */", false),
        ("int'", false),
    ])
    func safeTypeNames(typeName: String, isSafe: Bool) {
        #expect(typeName.isSafeSQLTypeName == isSafe)
    }

    @Test func commaSeparatedItemsTrimsAndDropsEmpties() {
        #expect(" a, b ,, c ".commaSeparatedItems == ["a", "b", "c"])
        #expect("".commaSeparatedItems.isEmpty)
    }
}

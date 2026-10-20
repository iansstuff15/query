import AppKit
import Testing
@testable import query

@MainActor
@Suite("SQLSyntaxHighlighter")
struct SQLSyntaxHighlighterTests {
    private func color(_ storage: NSTextStorage, at word: String) -> NSColor? {
        let range = (storage.string as NSString).range(of: word)
        return storage.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
    }

    @Test func colorsKeywordsTablesAndLiterals() {
        let storage = NSTextStorage(string: "SELECT name FROM customers WHERE id = 7 AND note = 'x' -- done")
        SQLSyntaxHighlighter.highlight(storage, tables: ["customers"])
        #expect(color(storage, at: "SELECT") == SyntaxPalette.color(for: .keyword))
        #expect(color(storage, at: "customers") == SyntaxPalette.color(for: .table))
        #expect(color(storage, at: "7") == SyntaxPalette.color(for: .number))
        #expect(color(storage, at: "'x'") == SyntaxPalette.color(for: .string))
        #expect(color(storage, at: "-- done") == SyntaxPalette.color(for: .comment))
        #expect(color(storage, at: "name") == SyntaxPalette.text)
    }

    @Test func rehighlightingResetsOldColors() {
        let storage = NSTextStorage(string: "FROM orders")
        SQLSyntaxHighlighter.highlight(storage, tables: ["orders"])
        storage.replaceCharacters(in: (storage.string as NSString).range(of: "orders"), with: "nothing")
        SQLSyntaxHighlighter.highlight(storage, tables: ["orders"])
        #expect(color(storage, at: "nothing") == SyntaxPalette.text)
    }

    @Test func highlightingCanBeTurnedOff() {
        let storage = NSTextStorage(string: "SELECT 1 FROM customers")
        SQLSyntaxHighlighter.highlight(storage, tables: ["customers"], colorsTokens: false)
        #expect(color(storage, at: "SELECT") == SyntaxPalette.text)
        #expect(color(storage, at: "customers") == SyntaxPalette.text)
    }
}

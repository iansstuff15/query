import AppKit

/// Colors the SQL in a text storage: resets everything to the base font and color, then
/// applies each token's color (keywords also get a heavier weight).
@MainActor
enum SQLSyntaxHighlighter {
    /// - Parameter colorsTokens: false (`ENABLE_SQL_SYNTAX_HIGHLIGHTING` off) leaves plain text.
    static func highlight(_ storage: NSTextStorage, tables: Set<String>, colorsTokens: Bool = true) {
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes([.font: SyntaxPalette.font, .foregroundColor: SyntaxPalette.text], range: full)
        defer { storage.endEditing() }
        guard colorsTokens else { return }
        for token in SQLTokenizer.tokens(in: storage.string, tables: tables) where NSMaxRange(token.range) <= storage.length {
            storage.addAttribute(.foregroundColor, value: SyntaxPalette.color(for: token.kind), range: token.range)
            if token.kind == .keyword {
                storage.addAttribute(.font, value: SyntaxPalette.keywordFont, range: token.range)
            }
        }
    }
}

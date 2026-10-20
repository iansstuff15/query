import AppKit

/// SQL editor colors (AppKit, for `NSTextView`), Xcode-style: keywords pink, table names teal,
/// strings red, numbers blue / gold, comments gray. Dynamic, so they follow light / dark and
/// Increase Contrast.
enum SyntaxPalette {
    static let text = NSColor.textColor

    static func color(for kind: SQLToken.Kind) -> NSColor {
        switch kind {
        case .keyword: NSColor(resource: .syntaxKeyword)
        case .table: NSColor(resource: .syntaxTable)
        case .string: NSColor(resource: .syntaxString)
        case .number: NSColor(resource: .syntaxNumber)
        case .comment: NSColor(resource: .syntaxComment)
        }
    }

    /// Monospaced at the callout text style's size, like the rest of the app's SQL.
    static var font: NSFont {
        NSFont.monospacedSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .callout).pointSize, weight: .regular)
    }

    /// The ▶ beside each runnable statement.
    static let runGlyph = NSColor(resource: .statusSuccess)
    static let gutterWidth: CGFloat = 22
    static let gutterGlyphSize: CGFloat = 11

    static var keywordFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .callout).pointSize, weight: .semibold)
    }
}

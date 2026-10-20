import Foundation

/// One runnable statement in the SQL editor: a line, or the part of a line between `;`s.
nonisolated struct SQLEditorStatement: Equatable, Sendable {
    /// The statement as it runs: trimmed, without its trailing `;`.
    let sql: String
    /// Where it is in the editor (UTF-16, as AppKit expects), trimmed of surrounding whitespace.
    let range: NSRange

    /// Identifies "the same query" for result tabs: whitespace collapsed, so re-running it (even
    /// reformatted) reuses its tab.
    var key: String { Self.key(for: sql) }

    static func key(for sql: String) -> String {
        sql.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

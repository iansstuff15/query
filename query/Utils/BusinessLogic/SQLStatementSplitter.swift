import Foundation

/// Splits the SQL editor's text into statements: each line is one, and `;` also ends one.
/// Semicolons and line breaks inside quotes or block comments don't split, and lines that are
/// only comments or blank are skipped.
nonisolated enum SQLStatementSplitter {
    static func statements(in text: String) -> [SQLEditorStatement] {
        let units = Array(text.utf16)
        var statements: [SQLEditorStatement] = []
        var start = 0
        var index = 0

        func close(at end: Int) {
            appendStatement(units, start, end, to: &statements)
            start = end + 1
        }

        while index < units.count {
            let unit = units[index]
            switch unit {
            case 0x27, 0x22, 0x60: // ' " `
                index += 1
                while index < units.count {
                    if units[index] == unit {
                        // '' inside a literal is an escaped quote.
                        if unit == 0x27, index + 1 < units.count, units[index + 1] == 0x27 { index += 2; continue }
                        break
                    }
                    index += 1
                }
            case 0x2D where index + 1 < units.count && units[index + 1] == 0x2D: // --
                while index + 1 < units.count, units[index + 1] != 0x0A { index += 1 }
            case 0x2F where index + 1 < units.count && units[index + 1] == 0x2A: // /*
                index += 2
                while index + 1 < units.count, !(units[index] == 0x2A && units[index + 1] == 0x2F) { index += 1 }
                index += 1
            case 0x3B, 0x0A: // ; or newline
                close(at: index)
            default:
                break
            }
            index += 1
        }
        if start < units.count { appendStatement(units, start, units.count, to: &statements) }
        return statements
    }

    /// The statements to run for a cursor or selection: those overlapping the selection, or the
    /// one the cursor is in (or at the end of).
    static func statements(in text: String, for selection: NSRange) -> [SQLEditorStatement] {
        let all = statements(in: text)
        if selection.length > 0 {
            return all.filter { NSIntersectionRange($0.range, selection).length > 0 }
        }
        return all.first { selection.location >= $0.range.location && selection.location <= NSMaxRange($0.range) }.map { [$0] } ?? []
    }

    private static func appendStatement(_ units: [UInt16], _ start: Int, _ end: Int, to statements: inout [SQLEditorStatement]) {
        var lower = start
        var upper = min(end, units.count)
        while lower < upper, isSpace(units[lower]) { lower += 1 }
        while upper > lower, isSpace(units[upper - 1]) { upper -= 1 }
        guard lower < upper else { return }
        let sql = String(utf16CodeUnits: Array(units[lower..<upper]), count: upper - lower)
        // Comment-only lines aren't statements.
        guard hasCode(sql) else { return }
        statements.append(SQLEditorStatement(sql: sql, range: NSRange(location: lower, length: upper - lower)))
    }

    private static func hasCode(_ sql: String) -> Bool {
        let tokens = SQLTokenizer.tokens(in: sql, tables: [])
        var remaining = sql as NSString
        for token in tokens.reversed() where token.kind == .comment {
            remaining = remaining.replacingCharacters(in: token.range, with: "") as NSString
        }
        return !(remaining as String).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func isSpace(_ unit: UInt16) -> Bool {
        unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D
    }
}

import Foundation

/// Splits the SQL editor's text into statements. Each line is a statement and `;` also ends
/// one, except that a formatted statement may continue onto following lines: a line break
/// doesn't split while a parenthesis is open, after a line ending in `,`, `(`, an operator or a
/// word that needs more (`SELECT`, `WHERE`, `AND`…), before an indented line, before a line
/// starting with a clause word (`FROM`, `WHERE`, `JOIN`, `ORDER`, `VALUES`…), or between a
/// `WITH` clause and its main query. A blank line or `;` always ends a statement. Semicolons and
/// line breaks inside quotes or block comments don't split, and lines that are only comments or
/// blank are skipped.
nonisolated enum SQLStatementSplitter {
    static func statements(in text: String) -> [SQLEditorStatement] {
        let units = Array(text.utf16)
        var statements: [SQLEditorStatement] = []
        var start = 0
        var index = 0
        /// The statement's code so far, without comments or string contents, for continuation rules.
        var code: [UInt16] = []
        var depth = 0

        func close(at end: Int) {
            appendStatement(units, start, end, to: &statements)
            start = end + 1
            code = []
            depth = 0
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
                code.append(0x27)
            case 0x2D where index + 1 < units.count && units[index + 1] == 0x2D: // --
                while index + 1 < units.count, units[index + 1] != 0x0A { index += 1 }
            case 0x2F where index + 1 < units.count && units[index + 1] == 0x2A: // /*
                index += 2
                while index + 1 < units.count, !(units[index] == 0x2A && units[index + 1] == 0x2F) { index += 1 }
                index += 1
                code.append(0x20)
            case 0x3B: // ;
                close(at: index)
            case 0x0A: // newline
                if continues(code: code, depth: depth, nextLine: line(units, from: index + 1)) {
                    code.append(0x20)
                } else {
                    close(at: index)
                }
            case 0x28: // (
                depth += 1
                code.append(unit)
            case 0x29: // )
                depth = max(depth - 1, 0)
                code.append(unit)
            default:
                code.append(unit)
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

    // MARK: - Continuation

    /// Clause words that can't start a statement, so a line starting with one continues the last.
    static let continuationWords: Set<String> = [
        "from", "where", "and", "or", "not", "group", "order", "having", "limit", "offset", "fetch", "join", "inner", "left", "right",
        "full", "cross", "natural", "outer", "on", "using", "union", "intersect", "except", "minus", "values", "set", "returning",
        "when", "then", "else", "end", "window", "into", "lateral", "partition", "over", "between", "like", "ilike", "in", "is",
        "asc", "desc", "nulls", "collate", "escape", "for", "straight_join",
    ]

    /// Words that need more after them, so a line ending with one continues onto the next.
    static let openEndedWords: Set<String> = [
        "select", "from", "where", "and", "or", "not", "join", "on", "by", "set", "values", "as", "in", "like", "ilike", "between",
        "then", "else", "when", "case", "distinct", "into", "union", "all", "with", "insert", "update", "delete", "having", "is",
        "exists", "table", "using", "over", "partition", "returning",
    ]

    private static let mainQueryWords: Set<String> = ["select", "insert", "update", "delete", "merge", "values", "table"]

    private static func continues(code: [UInt16], depth: Int, nextLine: [UInt16]) -> Bool {
        let statement = trimmed(code)
        // Nothing but comments so far, or a blank line next: the statement (if any) ends here.
        guard !statement.isEmpty, nextLine.contains(where: { !isSpace($0) }) else { return false }
        if depth > 0 { return true }
        if let last = statement.last, [0x2C, 0x28, 0x2B, 0x2D, 0x2A, 0x2F, 0x3D, 0x3C, 0x3E, 0x7C, 0x26, 0x25].contains(last) {
            return true // , ( + - * / = < > | & %
        }
        if let lastWord = lastWord(statement), openEndedWords.contains(lastWord) { return true }
        if let first = nextLine.first, first == 0x20 || first == 0x09 { return true } // indented
        guard let nextWord = firstWord(nextLine) else {
            // Starts with punctuation, such as ")" or "||".
            return nextLine.first(where: { !isSpace($0) }).map { $0 != 0x2D && $0 != 0x2F } ?? false
        }
        if continuationWords.contains(nextWord) { return true }
        return firstWord(statement) == "with" && mainQueryWords.contains(nextWord)
    }

    private static func line(_ units: [UInt16], from start: Int) -> [UInt16] {
        guard start < units.count else { return [] }
        var end = start
        while end < units.count, units[end] != 0x0A { end += 1 }
        return Array(units[start..<end])
    }

    private static func trimmed(_ units: [UInt16]) -> [UInt16] {
        var lower = 0
        var upper = units.count
        while lower < upper, isSpace(units[lower]) { lower += 1 }
        while upper > lower, isSpace(units[upper - 1]) { upper -= 1 }
        return Array(units[lower..<upper])
    }

    private static func firstWord(_ units: [UInt16]) -> String? {
        let text = trimmed(units)
        guard let first = text.first, SQLTokenizer.isWordStart(first) else { return nil }
        let word = text.prefix { SQLTokenizer.isWordPart($0) }
        return String(utf16CodeUnits: Array(word), count: word.count).lowercased()
    }

    private static func lastWord(_ units: [UInt16]) -> String? {
        let word = units.reversed().prefix { SQLTokenizer.isWordPart($0) }.reversed()
        guard let first = word.first, SQLTokenizer.isWordStart(first) else { return nil }
        return String(utf16CodeUnits: Array(word), count: word.count).lowercased()
    }

    // MARK: - Statements

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

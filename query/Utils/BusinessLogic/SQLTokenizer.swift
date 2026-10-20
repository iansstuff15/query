import Foundation

/// Splits SQL into the spans the console colors: reserved words, table names, string literals,
/// numbers and comments. Plain identifiers, operators and punctuation aren't returned.
///
/// A word that is both a keyword and a table name (a table called `order`) counts as a table
/// right after FROM / JOIN / INTO / UPDATE / TABLE, and as a keyword elsewhere.
nonisolated enum SQLTokenizer {
    static func tokens(in text: String, tables: Set<String>) -> [SQLToken] {
        let units = Array(text.utf16)
        var tokens: [SQLToken] = []
        var index = 0
        var previousWord: String?

        func span(_ kind: SQLToken.Kind, from start: Int) {
            tokens.append(SQLToken(kind: kind, range: NSRange(location: start, length: index - start)))
        }

        while index < units.count {
            let unit = units[index]
            let start = index
            if unit == dash, peek(units, index + 1) == dash {
                while index < units.count, units[index] != newline { index += 1 }
                span(.comment, from: start)
            } else if unit == slash, peek(units, index + 1) == star {
                index += 2
                while index < units.count, !(units[index] == star && peek(units, index + 1) == slash) { index += 1 }
                index = min(index + 2, units.count)
                span(.comment, from: start)
            } else if unit == singleQuote {
                index += 1
                while index < units.count {
                    if units[index] == singleQuote {
                        // '' is an escaped quote inside the literal.
                        if peek(units, index + 1) == singleQuote { index += 2; continue }
                        index += 1
                        break
                    }
                    index += 1
                }
                span(.string, from: start)
            } else if unit == doubleQuote || unit == backtick {
                index += 1
                while index < units.count, units[index] != unit { index += 1 }
                let name = String(utf16CodeUnits: Array(units[(start + 1)..<index]), count: index - start - 1)
                index = min(index + 1, units.count)
                if tables.contains(name.lowercased()) { span(.table, from: start) }
                previousWord = name.lowercased()
            } else if isDigit(unit) || (unit == dot && isDigit(peek(units, index + 1))) {
                while index < units.count, isDigit(units[index]) || units[index] == dot { index += 1 }
                if index < units.count, units[index] == 0x65 || units[index] == 0x45, // e / E
                   isDigit(peek(units, index + 1)) || ((peek(units, index + 1) == plus || peek(units, index + 1) == dash) && isDigit(peek(units, index + 2))) {
                    index += 2
                    while index < units.count, isDigit(units[index]) { index += 1 }
                }
                span(.number, from: start)
            } else if isWordStart(unit) {
                while index < units.count, isWordPart(units[index]) { index += 1 }
                let word = String(utf16CodeUnits: Array(units[start..<index]), count: index - start).lowercased()
                let isKeyword = SQLKeywords.lowercased.contains(word)
                let isTable = tables.contains(word)
                let expectsTable = previousWord.map(SQLKeywords.tableContext.contains) ?? false
                if isTable && (!isKeyword || expectsTable) {
                    span(.table, from: start)
                } else if isKeyword {
                    span(.keyword, from: start)
                }
                previousWord = word
            } else {
                index += 1
            }
        }
        return tokens
    }

    private static let dash: UInt16 = 0x2D
    private static let slash: UInt16 = 0x2F
    private static let star: UInt16 = 0x2A
    private static let plus: UInt16 = 0x2B
    private static let dot: UInt16 = 0x2E
    private static let newline: UInt16 = 0x0A
    private static let singleQuote: UInt16 = 0x27
    private static let doubleQuote: UInt16 = 0x22
    private static let backtick: UInt16 = 0x60

    private static func peek(_ units: [UInt16], _ index: Int) -> UInt16? {
        units.indices.contains(index) ? units[index] : nil
    }

    private static func isDigit(_ unit: UInt16?) -> Bool {
        guard let unit else { return false }
        return (0x30...0x39).contains(unit)
    }

    static func isWordStart(_ unit: UInt16) -> Bool {
        (0x41...0x5A).contains(unit) || (0x61...0x7A).contains(unit) || unit == 0x5F || unit > 0x7F
    }

    static func isWordPart(_ unit: UInt16) -> Bool {
        isWordStart(unit) || isDigit(unit) || unit == 0x24 // $
    }
}

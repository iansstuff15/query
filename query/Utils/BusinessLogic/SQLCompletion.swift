import Foundation

/// Suggestions for the word being typed in the SQL console: reserved words and table names.
/// Tables come first right after FROM / JOIN / INTO / UPDATE / TABLE, keywords first elsewhere,
/// and after `schema.` only that schema's tables are offered.
nonisolated enum SQLCompletion {
    struct Context: Equatable, Sendable {
        /// The partial word before the cursor (may be empty right after `schema.`).
        let prefix: String
        /// UTF-16 range of `prefix`, which the chosen suggestion replaces.
        let range: NSRange
        /// The word before a `.` in front of the prefix, such as a schema name.
        let qualifier: String?
        /// The word before the prefix (or its qualifier), lowercased.
        let previousWord: String?
    }

    /// What's being typed at `location` (UTF-16 offset) in `text`.
    static func context(in text: String, at location: Int) -> Context {
        let units = Array(text.utf16)
        let end = min(max(location, 0), units.count)
        var start = end
        while start > 0, SQLTokenizer.isWordPart(units[start - 1]) { start -= 1 }
        let prefix = string(units, start, end)

        var cursor = start
        var qualifier: String?
        if cursor > 0, units[cursor - 1] == 0x2E { // .
            var qualifierEnd = cursor - 1
            var qualifierStart = qualifierEnd
            // Quoted qualifiers: "public".customers
            if qualifierEnd > 0, units[qualifierEnd - 1] == 0x22 || units[qualifierEnd - 1] == 0x60 {
                let quote = units[qualifierEnd - 1]
                qualifierEnd -= 1
                qualifierStart = qualifierEnd
                while qualifierStart > 0, units[qualifierStart - 1] != quote { qualifierStart -= 1 }
                qualifier = string(units, qualifierStart, qualifierEnd)
                cursor = max(qualifierStart - 1, 0)
            } else {
                while qualifierStart > 0, SQLTokenizer.isWordPart(units[qualifierStart - 1]) { qualifierStart -= 1 }
                qualifier = string(units, qualifierStart, qualifierEnd)
                cursor = qualifierStart
            }
            if qualifier?.isEmpty == true { qualifier = nil }
        }

        while cursor > 0, isSpace(units[cursor - 1]) { cursor -= 1 }
        var wordStart = cursor
        while wordStart > 0, SQLTokenizer.isWordPart(units[wordStart - 1]) { wordStart -= 1 }
        let previous = string(units, wordStart, cursor).lowercased()

        return Context(
            prefix: prefix, range: NSRange(location: start, length: end - start), qualifier: qualifier,
            previousWord: previous.isEmpty ? nil : previous
        )
    }

    /// Suggestions for `context`, best first. Keywords follow the case being typed (`sel` →
    /// `select`, `SEL` or `Sel` → `SELECT`); table names keep their own case.
    static func suggestions(
        for context: Context, objects: [DatabaseObject], keywords: [String] = SQLKeywords.all, limit: Int = AppConfig.sqlCompletionLimit
    ) -> [String] {
        let prefix = context.prefix.lowercased()
        func matches(_ candidate: String) -> Bool {
            let lowered = candidate.lowercased()
            return lowered.hasPrefix(prefix) && lowered != prefix
        }

        if let qualifier = context.qualifier?.lowercased() {
            let inSchema = objects.filter { $0.schema.lowercased() == qualifier }
            // A table alias or column qualifier rather than a schema: nothing to suggest.
            guard !inSchema.isEmpty else { return [] }
            return Array(unique(inSchema.map(\.name).filter(matches).sorted(by: shorterThenAlphabetical)).prefix(limit))
        }

        guard !prefix.isEmpty || context.previousWord.map(SQLKeywords.tableContext.contains) == true else { return [] }
        let tables = unique(objects.map(\.name).filter(matches).sorted(by: shorterThenAlphabetical))
        let lowercaseKeywords = context.prefix == context.prefix.lowercased()
        let words = prefix.isEmpty ? [] : keywords.filter(matches).sorted(by: shorterThenAlphabetical)
            .map { lowercaseKeywords ? $0.lowercased() : $0.uppercased() }
        let tablesFirst = context.previousWord.map(SQLKeywords.tableContext.contains) ?? false
        return Array(unique(tablesFirst ? tables + words : words + tables).prefix(limit))
    }

    private static func shorterThenAlphabetical(_ lhs: String, _ rhs: String) -> Bool {
        lhs.count == rhs.count ? lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending : lhs.count < rhs.count
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func string(_ units: [UInt16], _ start: Int, _ end: Int) -> String {
        guard start < end else { return "" }
        return String(utf16CodeUnits: Array(units[start..<end]), count: end - start)
    }

    private static func isSpace(_ unit: UInt16) -> Bool {
        unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D
    }
}

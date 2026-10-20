import Foundation

/// Matches a query against a name, case-insensitively, using a `MatchingStrategy`.
///
/// Fuzzy matching is a subsequence match that rewards consecutive characters and word
/// boundaries (`_`, `-`, `.`, space, camelCase), like Open Anything / ⌘P palettes.
nonisolated struct TextMatcher: Sendable {
    let strategy: MatchingStrategy

    private enum Score {
        static let character = 16
        static let consecutive = 15
        static let boundary = 30
        static let prefix = 50
        static let exact = 100
        static let maxLeadingPenalty = 15
    }

    func match(_ query: String, in candidate: String) -> TextMatch? {
        let needle = query.trimmingCharacters(in: .whitespaces).map { $0.lowercased() }
        guard !needle.isEmpty else { return TextMatch(score: 0, offsets: []) }
        let original = Array(candidate)
        let haystack = original.map { $0.lowercased() }
        guard needle.count <= haystack.count else { return nil }

        switch strategy {
        case .prefix:
            guard haystack.starts(with: needle) else { return nil }
            return TextMatch(score: bonus(needle, haystack) - haystack.count, offsets: Array(needle.indices))
        case .contains:
            guard let start = firstRange(of: needle, in: haystack) else { return nil }
            let score = bonus(needle, haystack) - start * 2 - haystack.count
            return TextMatch(score: score, offsets: Array(start..<(start + needle.count)))
        case .fuzzy:
            return fuzzy(needle, haystack, original)
        }
    }

    private func fuzzy(_ needle: [String], _ haystack: [String], _ original: [Character]) -> TextMatch? {
        var offsets: [Int] = []
        var score = 0
        var searchFrom = 0
        for (index, character) in needle.enumerated() {
            guard let found = nextOffset(
                of: character,
                in: haystack,
                from: searchFrom,
                remaining: needle[(index + 1)...],
                original: original
            ) else {
                return nil
            }
            score += Score.character
            if let previous = offsets.last {
                score += found == previous + 1 ? Score.consecutive : -(found - previous - 1)
            }
            if isBoundary(found, in: original) { score += Score.boundary }
            offsets.append(found)
            searchFrom = found + 1
        }
        score -= min(offsets.first ?? 0, Score.maxLeadingPenalty)
        score += bonus(needle, haystack) - haystack.count
        return TextMatch(score: score, offsets: offsets)
    }

    /// Next occurrence of `character`. When that occurrence is mid-word, a later word-boundary
    /// occurrence is preferred (so `oi` hits **o**rder_**i**tems), but only if the rest of the
    /// query still matches after it.
    private func nextOffset(
        of character: String,
        in haystack: [String],
        from start: Int,
        remaining: ArraySlice<String>,
        original: [Character]
    ) -> Int? {
        guard start < haystack.count, let first = haystack[start...].firstIndex(of: character) else { return nil }
        if first == start || isBoundary(first, in: original) { return first }
        let boundary = haystack[first...].indices.first { offset in
            haystack[offset] == character
                && isBoundary(offset, in: original)
                && isSubsequence(remaining, of: haystack[(offset + 1)...])
        }
        return boundary ?? first
    }

    private func isSubsequence(_ needle: ArraySlice<String>, of haystack: ArraySlice<String>) -> Bool {
        var iterator = needle.makeIterator()
        var next = iterator.next()
        for character in haystack where character == next {
            next = iterator.next()
        }
        return next == nil
    }

    private func isBoundary(_ offset: Int, in original: [Character]) -> Bool {
        guard offset > 0 else { return true }
        let previous = original[offset - 1]
        if "_-. /".contains(previous) { return true }
        return original[offset].isUppercase && previous.isLowercase
    }

    private func bonus(_ needle: [String], _ haystack: [String]) -> Int {
        if needle == haystack { return Score.exact + Score.prefix }
        return haystack.starts(with: needle) ? Score.prefix : 0
    }

    private func firstRange(of needle: [String], in haystack: [String]) -> Int? {
        guard needle.count <= haystack.count else { return nil }
        return (0...(haystack.count - needle.count)).first { start in
            haystack[start..<(start + needle.count)].elementsEqual(needle)
        }
    }
}

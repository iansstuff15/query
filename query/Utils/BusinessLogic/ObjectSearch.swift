import Foundation

/// Searches the cached object list locally — no database round-trip, like TablePlus's
/// sidebar filter and Open Anything.
nonisolated enum ObjectSearch {
    /// Ranked matches for Open Anything. A query with a dot (`sales.ord`) restricts the schema.
    static func rank(_ objects: [DatabaseObject], query: String, matcher: TextMatcher) -> [SearchMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return objects.map { SearchMatch(object: $0, score: 0, nameOffsets: []) }
        }
        let (schemaQuery, nameQuery) = split(trimmed)
        let matches = objects.compactMap { object -> SearchMatch? in
            if let schemaQuery, !schemaQuery.isEmpty,
               object.schema.range(of: schemaQuery, options: .caseInsensitive) == nil {
                return nil
            }
            guard let match = matcher.match(nameQuery, in: object.name) else { return nil }
            return SearchMatch(object: object, score: match.score, nameOffsets: match.offsets)
        }
        return matches.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.object.name.count != rhs.object.name.count { return lhs.object.name.count < rhs.object.name.count }
            return lhs.object.id < rhs.object.id
        }
    }

    /// Sidebar filtering keeps catalog order and groups by schema.
    static func sections(_ objects: [DatabaseObject], query: String, matcher: TextMatcher) -> [SchemaSection] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let visible = trimmed.isEmpty ? objects : objects.filter { matcher.match(trimmed, in: $0.name) != nil }
        var order: [String] = []
        var grouped: [String: [DatabaseObject]] = [:]
        for object in visible {
            if grouped[object.schema] == nil { order.append(object.schema) }
            grouped[object.schema, default: []].append(object)
        }
        return order.map { SchemaSection(schema: $0, objects: grouped[$0] ?? []) }
    }

    private static func split(_ query: String) -> (schema: String?, name: String) {
        guard let dot = query.lastIndex(of: ".") else { return (nil, query) }
        return (String(query[..<dot]), String(query[query.index(after: dot)...]))
    }
}

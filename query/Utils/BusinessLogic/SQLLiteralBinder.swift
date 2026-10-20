import Foundation

/// Inlines positional `?` bindings as SQL string literals, for wire protocols with no bind
/// step (the PostgreSQL simple-query protocol used for Vertica).
///
/// Markers inside `'…'` literals, `"…"` identifiers and comments are left alone; values are
/// single-quoted with `'` doubled (standard-conforming strings) and NUL bytes removed.
nonisolated enum SQLLiteralBinder {
    static func bind(_ statement: SQLStatement) throws -> String {
        var output = ""
        var values = statement.bindings.makeIterator()
        var characters = Array(statement.sql)
        var index = 0
        var quote: Character?
        characters.append("\0")
        while index < characters.count - 1 {
            let character = characters[index]
            if let open = quote {
                output.append(character)
                if character == open {
                    if characters[index + 1] == open {
                        output.append(characters[index + 1])
                        index += 1
                    } else {
                        quote = nil
                    }
                }
            } else if character == "'" || character == "\"" {
                quote = character
                output.append(character)
            } else if character == "-", characters[index + 1] == "-" {
                while index < characters.count - 1, characters[index] != "\n" {
                    output.append(characters[index])
                    index += 1
                }
                continue
            } else if character == "?" {
                guard let value = values.next() else { throw DatabaseError.queryFailed }
                output.append(literal(value))
            } else {
                output.append(character)
            }
            index += 1
        }
        guard values.next() == nil else { throw DatabaseError.queryFailed }
        return output
    }

    static func literal(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "\0", with: "").replacingOccurrences(of: "'", with: "''") + "'"
    }
}

import Foundation

nonisolated extension String {
    /// A double-quoted SQL identifier with embedded quotes doubled.
    var quotedIdentifier: String {
        "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// A single-quoted PostgreSQL string literal (standard-conforming strings: `'` doubled,
    /// backslashes literal), for statements that can't take bind parameters (CREATE ROLE).
    var postgresStringLiteral: String {
        "'" + replacingOccurrences(of: "'", with: "''") + "'"
    }

    /// A single-quoted MySQL / MariaDB string literal (`\` and `'` escaped), for statements that
    /// can't take bind parameters (CREATE USER, GRANT).
    var mySQLStringLiteral: String {
        "'" + replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "''") + "'"
    }

    /// A MySQL / MariaDB backtick-quoted identifier.
    var mySQLIdentifier: String {
        "`" + replacingOccurrences(of: "`", with: "``") + "`"
    }

    /// Escapes `\`, `%` and `_` so the text matches literally inside a LIKE pattern.
    var escapedLikePattern: String {
        var escaped = ""
        for character in self {
            if character == "\\" || character == "%" || character == "_" {
                escaped.append("\\")
            }
            escaped.append(character)
        }
        return escaped
    }

    /// True for server-formatted type names safe to splice into `CAST(… AS type)`.
    var isSafeSQLTypeName: Bool {
        guard !isEmpty, !contains("--"), !contains("/*"), !contains(";") else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_ ,()[].\""))
        return unicodeScalars.allSatisfy(allowed.contains)
    }

    /// Splits a comma-separated list, trimming whitespace and dropping empty items.
    var commaSeparatedItems: [String] {
        split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

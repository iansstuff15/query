import Foundation

/// Decides whether arbitrary text (the clipboard) is a connection string for an engine.
/// Stricter than `ConnectionStringParser`, which also accepts loose forms (a bare word is a valid
/// Oracle host, any path a SQLite file) that only make sense when the user typed them on purpose.
nonisolated enum ConnectionStringDetector {
    /// The trimmed connection string, or `nil` when `text` doesn't look like one for `engine`.
    static func detect(_ text: String, for engine: DatabaseEngine) -> String? {
        let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (8...4_096).contains(candidate.count), !candidate.contains(where: \.isNewline),
              looksLikeConnectionString(candidate, for: engine),
              (try? ConnectionStringParser.parse(candidate, for: engine)) != nil
        else { return nil }
        return candidate
    }

    private static func looksLikeConnectionString(_ candidate: String, for engine: DatabaseEngine) -> Bool {
        switch engine {
        case .sqlite, .duckDB:
            return hasFileScheme(candidate) || isDatabaseFilePath(candidate)
        case .sqlServer where isADO(candidate):
            return true
        case .oracle where isEZConnect(candidate):
            return true
        default:
            break
        }
        guard !candidate.contains(where: \.isWhitespace), let scheme = scheme(of: candidate) else { return false }
        // Plain web links are common clipboard contents; database endpoints nearly always name a port.
        if ["http", "https", "ws", "wss"].contains(scheme) {
            return URLComponents(string: candidate)?.port != nil
        }
        return true
    }

    /// `postgres` for `postgres://…`, `oracle` for `jdbc:oracle:thin:@…`.
    private static func scheme(of candidate: String) -> String? {
        let lowered = candidate.lowercased()
        if lowered.hasPrefix("jdbc:") {
            return lowered.dropFirst(5).split(separator: ":").first.map(String.init)
        }
        guard let separator = lowered.range(of: "://") else { return nil }
        return String(lowered[..<separator.lowerBound])
    }

    private static func hasFileScheme(_ candidate: String) -> Bool {
        let lowered = candidate.lowercased()
        return ["sqlite:", "sqlite3:", "duckdb:", "file:"].contains { lowered.hasPrefix($0) }
    }

    private static func isDatabaseFilePath(_ candidate: String) -> Bool {
        guard candidate.hasPrefix("/") || candidate.hasPrefix("~/") else { return false }
        let ext = URL(filePath: candidate).pathExtension.lowercased()
        return ["sqlite", "sqlite3", "db", "db3", "duckdb"].contains(ext)
    }

    /// `Server=host,1433;Database=app;…`
    private static func isADO(_ candidate: String) -> Bool {
        candidate.contains(";") && candidate.contains(#/(?i)(^|;)\s*(server|data source|address|addr)\s*=/#)
    }

    /// `user/password@host:port/service` or `host:port/service`.
    private static func isEZConnect(_ candidate: String) -> Bool {
        candidate.wholeMatch(of: #/[^\s/@]+/[^\s@]*@(//)?[\w.-]+(:\d+)?(/[\w.$#-]+)?/#) != nil
            || candidate.wholeMatch(of: #/[\w.-]+:\d+/[\w.$#-]+/#) != nil
    }
}

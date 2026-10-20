import Foundation

/// Limits and identifiers. The limits can be tuned in `query-Info.plist` (keys in capitals);
/// out-of-range values are clamped and missing ones use the defaults here.
nonisolated enum AppConfig {
    /// Rows fetched per table page, like TablePlus's "Limit rows returned". `ROW_LIMIT`
    static let rowLimit = InfoPlist.int("ROW_LIMIT", default: 300, in: 1...10_000)
    /// Maximum Open Anything results rendered. `OPEN_ANYTHING_RESULT_LIMIT`
    static let paletteResultLimit = InfoPlist.int("OPEN_ANYTHING_RESULT_LIMIT", default: 50, in: 10...500)
    static let defaultPort = 5_432
    /// Long enough to read the splash without slowing down launch. `SPLASH_MINIMUM_MILLISECONDS`
    static let splashMinimumMilliseconds = InfoPlist.int("SPLASH_MINIMUM_MILLISECONDS", default: 1_400, in: 0...10_000)
    /// How long the welcome screen waits for each saved connection before marking it
    /// unreachable. `CONNECTION_CHECK_TIMEOUT_SECONDS`
    static let connectionCheckTimeout: Duration = .seconds(InfoPlist.int("CONNECTION_CHECK_TIMEOUT_SECONDS", default: 5, in: 1...60))
    /// SQL console runs kept per connection. `SQL_HISTORY_LIMIT`
    static let sqlHistoryLimit = InfoPlist.int("SQL_HISTORY_LIMIT", default: 200, in: 1...5_000)
    /// Most suggestions shown in the SQL editor's completion list. `SQL_COMPLETION_LIMIT`
    static let sqlCompletionLimit = InfoPlist.int("SQL_COMPLETION_LIMIT", default: 40, in: 5...200)
    /// Largest `.sql` file the editor opens. `SQL_FILE_MAX_MEGABYTES`
    static let sqlFileMaxBytes = InfoPlist.int("SQL_FILE_MAX_MEGABYTES", default: 5, in: 1...100) * 1_000_000
    static let keychainService = "by-ian.query.postgres"
    static let logSubsystem = Bundle.main.bundleIdentifier ?? "by-ian.query"
}

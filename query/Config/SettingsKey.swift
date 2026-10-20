import Foundation

/// `@AppStorage` / `UserDefaults` keys.
nonisolated enum SettingsKey {
    static let host = "connection.host"
    static let port = "connection.port"
    static let database = "connection.database"
    static let username = "connection.username"
    static let tlsMode = "connection.tlsMode"
    static let matchingStrategy = "search.matchingStrategy"
    static let theme = "display.theme"
    static let language = "display.language"
    static let secretStore = "store.secrets"
    /// Set once the user finishes the startup configuration.
    static let setupCompleted = "setup.completed"
    /// The newest release whose notes were shown in What's New.
    static let whatsNewSeenVersion = "whatsNew.seenVersion"
}

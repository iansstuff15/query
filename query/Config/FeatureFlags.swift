import Foundation

/// Feature toggles from the app's Info.plist (`query-Info.plist`). Every feature is on unless its
/// key says otherwise; the two `ALWAYS_SHOW_…` keys are off unless set.
nonisolated struct FeatureFlags: Equatable, Sendable {
    /// `ALWAYS_SHOW_STARTUP_CONFIG`: open the startup configuration on every launch, not just the first.
    let alwaysShowStartupConfig: Bool
    /// `ALWAYS_SHOW_CHANGELOG`: open What's New on every launch, not just after an update.
    let alwaysShowChangelog: Bool
    /// `ENABLE_SQL_CONSOLE`: the SQL editor in the workspace's right panel.
    let sqlConsole: Bool
    /// `ENABLE_SQL_HISTORY`: the History tab, and recording statements that run.
    let sqlHistory: Bool
    /// `ENABLE_SQL_AUTOCOMPLETE`: suggestions while typing SQL.
    let sqlAutocomplete: Bool
    /// `ENABLE_SQL_SYNTAX_HIGHLIGHTING`: colors in the SQL editor.
    let sqlSyntaxHighlighting: Bool
    /// `ENABLE_ROW_EDITING`: the Row tab, for editing a selected table row.
    let rowEditing: Bool
    /// `ENABLE_CLIPBOARD_CONNECTION_STRINGS`: fill the connection sheet from a copied connection string.
    let clipboardConnectionStrings: Bool
    /// `ENABLE_CONNECTION_HEALTH_CHECKS`: test recent connections on the welcome screen.
    let connectionHealthChecks: Bool
    /// `ENABLE_KEYCHAIN_STORE`: offer the macOS Keychain as a secret store.
    let keychainStore: Bool
    /// `ENABLE_THEMES`: color themes (Display); off keeps the system look.
    let themes: Bool
    /// `ENABLE_LANGUAGE_SETTING`: the Language step and Settings tab.
    let languageSetting: Bool

    static let alwaysShowStartupConfigKey = "ALWAYS_SHOW_STARTUP_CONFIG"
    static let alwaysShowChangelogKey = "ALWAYS_SHOW_CHANGELOG"

    init(infoDictionary info: [String: Any]) {
        alwaysShowStartupConfig = InfoPlist.bool(Self.alwaysShowStartupConfigKey, default: false, info: info)
        alwaysShowChangelog = InfoPlist.bool(Self.alwaysShowChangelogKey, default: false, info: info)
        sqlConsole = InfoPlist.bool("ENABLE_SQL_CONSOLE", default: true, info: info)
        sqlHistory = InfoPlist.bool("ENABLE_SQL_HISTORY", default: true, info: info)
        sqlAutocomplete = InfoPlist.bool("ENABLE_SQL_AUTOCOMPLETE", default: true, info: info)
        sqlSyntaxHighlighting = InfoPlist.bool("ENABLE_SQL_SYNTAX_HIGHLIGHTING", default: true, info: info)
        rowEditing = InfoPlist.bool("ENABLE_ROW_EDITING", default: true, info: info)
        clipboardConnectionStrings = InfoPlist.bool("ENABLE_CLIPBOARD_CONNECTION_STRINGS", default: true, info: info)
        connectionHealthChecks = InfoPlist.bool("ENABLE_CONNECTION_HEALTH_CHECKS", default: true, info: info)
        keychainStore = InfoPlist.bool("ENABLE_KEYCHAIN_STORE", default: true, info: info)
        themes = InfoPlist.bool("ENABLE_THEMES", default: true, info: info)
        languageSetting = InfoPlist.bool("ENABLE_LANGUAGE_SETTING", default: true, info: info)
    }

    static let current = FeatureFlags(infoDictionary: InfoPlist.main)

    /// Everything on, for previews and tests.
    static let allEnabled = FeatureFlags(infoDictionary: [:])
}

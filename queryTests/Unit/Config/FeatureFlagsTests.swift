import Foundation
import Testing
@testable import query

@Suite("FeatureFlags")
struct FeatureFlagsTests {
    @Test func readsBooleansAndStrings() {
        let flags = FeatureFlags(infoDictionary: ["ALWAYS_SHOW_STARTUP_CONFIG": true, "ALWAYS_SHOW_CHANGELOG": "YES"])
        #expect(flags.alwaysShowStartupConfig)
        #expect(flags.alwaysShowChangelog)
    }

    @Test func missingOrFalseIsOff() {
        let flags = FeatureFlags(infoDictionary: ["ALWAYS_SHOW_STARTUP_CONFIG": false, "ALWAYS_SHOW_CHANGELOG": "nope"])
        #expect(!flags.alwaysShowStartupConfig)
        #expect(!flags.alwaysShowChangelog)
        #expect(!FeatureFlags(infoDictionary: [:]).alwaysShowChangelog)
    }

    @Test func theAppsInfoPlistTurnsBothOn() {
        #expect(FeatureFlags.current.alwaysShowStartupConfig)
        #expect(FeatureFlags.current.alwaysShowChangelog)
    }

    @Test func setupShowsOnFirstLaunchOrAlwaysButNeverUnderTests() throws {
        let suite = "query.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let app = LaunchOptions(arguments: [], environment: [:])
        let off = FeatureFlags(infoDictionary: [:])
        let always = FeatureFlags(infoDictionary: ["ALWAYS_SHOW_STARTUP_CONFIG": true])
        #expect(AppEnvironment.needsSetup(options: app, flags: off, defaults: defaults))
        defaults.set(true, forKey: SettingsKey.setupCompleted)
        #expect(!AppEnvironment.needsSetup(options: app, flags: off, defaults: defaults))
        #expect(AppEnvironment.needsSetup(options: app, flags: always, defaults: defaults))
        #expect(!AppEnvironment.needsSetup(options: LaunchOptions(arguments: ["-UITesting"], environment: [:]), flags: always, defaults: defaults))
    }

    @Test func featuresAreOnUnlessTurnedOff() {
        let all = FeatureFlags.allEnabled
        #expect(all.sqlConsole && all.sqlHistory && all.sqlAutocomplete && all.sqlSyntaxHighlighting && all.rowEditing)
        #expect(all.clipboardConnectionStrings && all.connectionHealthChecks && all.keychainStore && all.themes && all.languageSetting)
        #expect(!all.alwaysShowStartupConfig && !all.alwaysShowChangelog)
        let off = FeatureFlags(infoDictionary: ["ENABLE_ROW_EDITING": false, "ENABLE_SQL_HISTORY": "NO", "ENABLE_THEMES": 0])
        #expect(!off.rowEditing && !off.sqlHistory && !off.themes)
        #expect(off.sqlConsole)
    }

    @Test func theAppsInfoPlistTurnsEveryFeatureOn() {
        let flags = FeatureFlags.current
        #expect(flags.sqlConsole && flags.sqlHistory && flags.sqlAutocomplete && flags.sqlSyntaxHighlighting && flags.rowEditing)
        #expect(flags.clipboardConnectionStrings && flags.connectionHealthChecks && flags.keychainStore && flags.themes && flags.languageSetting)
        for key in ["ENABLE_SQL_CONSOLE", "ENABLE_SQL_HISTORY", "ENABLE_SQL_AUTOCOMPLETE", "ENABLE_SQL_SYNTAX_HIGHLIGHTING", "ENABLE_ROW_EDITING",
                    "ENABLE_CLIPBOARD_CONNECTION_STRINGS", "ENABLE_CONNECTION_HEALTH_CHECKS", "ENABLE_KEYCHAIN_STORE", "ENABLE_THEMES",
                    "ENABLE_LANGUAGE_SETTING"] {
            #expect(InfoPlist.main[key] != nil, "\(key) is missing from query-Info.plist")
        }
    }

    @Test func clipboardPickupCanBeTurnedOff() {
        let app = LaunchOptions(arguments: [], environment: [:])
        #expect(AppEnvironment.makeClipboard(options: app, flags: FeatureFlags(infoDictionary: ["ENABLE_CLIPBOARD_CONNECTION_STRINGS": false])) is EmptyClipboard)
        #expect(AppEnvironment.makeClipboard(options: app, flags: .allEnabled) is SystemClipboard)
    }
}

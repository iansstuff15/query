import Foundation
import Testing
@testable import query

@Suite("AppLanguage")
struct AppLanguageTests {
    @Test func eachLanguageNamesItself() {
        #expect(AppLanguage.system.nativeName == nil)
        #expect(AppLanguage.system.code == nil)
        #expect(AppLanguage.spanish.nativeName == "Español")
        #expect(AppLanguage.french.nativeName == "Français")
        #expect(AppLanguage.german.nativeName == "Deutsch")
        #expect(AppLanguage.japanese.nativeName == "日本語")
    }

    @Test func applyingSetsOrClearsThePerAppLanguage() throws {
        let suite = "query.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preference = LanguagePreference(defaults: defaults)
        preference.apply(.german)
        #expect(defaults.stringArray(forKey: LanguagePreference.appleLanguagesKey) == ["de"])
        preference.apply(.system)
        // Removing the app's own value falls back to the system's language order.
        #expect(defaults.persistentDomain(forName: suite)?[LanguagePreference.appleLanguagesKey] == nil)
    }

    /// Every language the picker offers ships with the app, fully translated.
    @Test(arguments: AppLanguage.allCases.compactMap(\.code))
    func everyLanguageIsBundled(code: String) throws {
        let path = try #require(Bundle.main.path(forResource: code, ofType: "lproj"), "\(code).lproj missing")
        let bundle = try #require(Bundle(path: path))
        let expected = ["es": "Ejecutar todo", "fr": "Tout exécuter", "de": "Alle ausführen", "ja": "すべて実行", "en": "Run All"][code]
        #expect(bundle.localizedString(forKey: "Run All", value: nil, table: nil) == expected)
    }
}

import Foundation

/// Applies the chosen language for the next launch through macOS's per-app language setting
/// (`AppleLanguages`), which menus and AppKit text read at startup. SwiftUI text switches right
/// away through the `localized()` modifier.
nonisolated struct LanguagePreference: @unchecked Sendable {
    static let appleLanguagesKey = "AppleLanguages"

    var defaults: UserDefaults = .standard

    func apply(_ language: AppLanguage) {
        if let code = language.code {
            defaults.set([code], forKey: Self.appleLanguagesKey)
        } else {
            defaults.removeObject(forKey: Self.appleLanguagesKey)
        }
    }
}

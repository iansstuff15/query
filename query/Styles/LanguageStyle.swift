import SwiftUI

/// Shows SwiftUI text in the user's chosen language right away (the rest of the app follows at
/// the next launch, through `LanguagePreference`).
struct LanguageStyle: ViewModifier {
    @AppStorage(SettingsKey.language) private var language: AppLanguage = .system
    @Environment(\.featureFlags) private var flags

    func body(content: Content) -> some View {
        if flags.languageSetting, let locale = language.locale {
            content.environment(\.locale, locale)
        } else {
            content
        }
    }
}

extension View {
    /// Uses the user's chosen language for this window's SwiftUI text.
    func localized() -> some View {
        modifier(LanguageStyle())
    }
}

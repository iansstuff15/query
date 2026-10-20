import SwiftUI

/// The display language, also offered in the startup configuration.
struct LanguageSettingsView: View {
    @AppStorage(SettingsKey.language) private var language: AppLanguage = .system

    var body: some View {
        Form {
            Section {
                LanguagePicker(selection: $language)
            } footer: {
                Text(L10n.languageSectionDetail).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: language) { _, language in LanguagePreference().apply(language) }
    }
}

#Preview {
    LanguageSettingsView()
}

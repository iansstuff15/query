import SwiftUI

/// The display language: System Default, or one of the app's languages, each by its own name
/// ("Español") with the name in the current language beneath it ("Spanish").
struct LanguagePicker: View {
    @Binding var selection: AppLanguage
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Picker(selection: $selection) {
                ForEach(AppLanguage.allCases) { language in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        if let nativeName = language.nativeName {
                            Text(verbatim: nativeName)
                            if let translated = language.code.flatMap({ locale.localizedString(forLanguageCode: $0) }), translated != nativeName {
                                Text(verbatim: translated.localizedCapitalized)
                                    .font(Theme.Typography.footer)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(L10n.languageSystem)
                            Text(L10n.languageSystemDetail)
                                .font(Theme.Typography.footer)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(language)
                    .accessibilityIdentifier(AccessibilityID.Setup.language(language.rawValue))
                }
            } label: {
                Text(L10n.languageSection)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .accessibilityIdentifier(AccessibilityID.Setup.languagePicker)

            Label(L10n.languageRelaunchNote, systemImage: "arrow.clockwise")
                .font(Theme.Typography.footer)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    @Previewable @State var language = AppLanguage.spanish
    LanguagePicker(selection: $language)
        .frame(width: 420)
        .padding()
}

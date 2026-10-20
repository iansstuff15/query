import SwiftUI

/// The color theme, also offered in the startup configuration.
struct DisplaySettingsView: View {
    @AppStorage(SettingsKey.theme) private var theme: AppTheme = .classic

    var body: some View {
        Form {
            Section {
                ThemePicker(selection: $theme)
            } footer: {
                Text(L10n.displaySectionDetail).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    DisplaySettingsView()
}

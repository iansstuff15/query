import SwiftUI

/// Preferences window. Language and Display appear only when their features are on in the
/// Info.plist.
struct SettingsView: View {
    let switcher: any SecretStoreSwitching
    var flags: FeatureFlags = .current

    var body: some View {
        TabView {
            if flags.languageSetting {
                LanguageSettingsView()
                    .tabItem { Text(L10n.languageSection) }
            }
            if flags.themes {
                DisplaySettingsView()
                    .tabItem { Text(L10n.displaySection) }
            }
            StoreSettingsView(switcher: switcher, offersKeychain: flags.keychainStore)
                .tabItem { Text(L10n.storeSection) }
            SearchSettingsView()
                .tabItem { Text(L10n.search) }
        }
        .frame(width: Theme.Layout.settingsWidth)
    }
}

#Preview {
    SettingsView(switcher: SwitchableCredentialStore(
        stores: [.sqlite: EphemeralCredentialStore(), .keychain: EphemeralCredentialStore()], active: .sqlite
    ))
}

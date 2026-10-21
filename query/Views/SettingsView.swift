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
                    .tabItem { Label(L10n.languageSection, systemImage: "globe") }
            }
            if flags.themes {
                DisplaySettingsView()
                    .tabItem { Label(L10n.displaySection, systemImage: "paintpalette") }
            }
            StoreSettingsView(switcher: switcher, offersKeychain: flags.keychainStore)
                .tabItem { Label(L10n.storeSection, systemImage: "lock.rectangle.stack") }
            SearchSettingsView()
                .tabItem { Label(L10n.search, systemImage: "magnifyingglass") }
        }
        .frame(width: Theme.Layout.settingsWidth)
    }
}

#Preview {
    SettingsView(switcher: SwitchableCredentialStore(
        stores: [.sqlite: EphemeralCredentialStore(), .keychain: EphemeralCredentialStore()], active: .sqlite
    ))
}

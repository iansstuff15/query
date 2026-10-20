import SwiftUI

/// Where saved passwords live; changing it moves them right away.
struct StoreSettingsView: View {
    @State private var model: StartupConfigurationViewModel

    init(switcher: any SecretStoreSwitching, offersKeychain: Bool = true) {
        _model = State(initialValue: StartupConfigurationViewModel(switcher: switcher, offersKeychain: offersKeychain))
    }

    var body: some View {
        Form {
            Section {
                SecretStorePicker(
                    selection: $model.selectedStore, kinds: model.storeKinds, isApplying: model.isApplying, didFailToSwitch: model.didFailToSwitch
                )
            } footer: {
                Text(L10n.storeSectionDetail).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: model.selectedStore) { _, selected in
            guard selected != model.activeStore else { return }
            Task { await model.applyStore() }
        }
    }
}

#Preview {
    StoreSettingsView(switcher: SwitchableCredentialStore(
        stores: [.sqlite: EphemeralCredentialStore(), .keychain: EphemeralCredentialStore()], active: .sqlite
    ))
}

import SwiftUI

/// SQLite (default) or Keychain for saved passwords, each with a line on the trade-off.
struct SecretStorePicker: View {
    @Binding var selection: SecretStoreKind
    /// The stores offered (the Keychain is left out when `ENABLE_KEYCHAIN_STORE` is off).
    var kinds: [SecretStoreKind] = SecretStoreKind.allCases
    let isApplying: Bool
    let didFailToSwitch: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Picker(selection: $selection) {
                ForEach(kinds) { kind in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Label(L10n.storeName(kind), systemImage: kind.systemImage)
                        Text(L10n.storeDescription(kind))
                            .font(Theme.Typography.footer)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .tag(kind)
                    .accessibilityIdentifier(AccessibilityID.Setup.store(kind.rawValue))
                }
            } label: {
                Text(L10n.storeSection)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .disabled(isApplying)
            .accessibilityIdentifier(AccessibilityID.Setup.storePicker)

            if isApplying {
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text(L10n.storeMoving).foregroundStyle(.secondary)
                }
                .font(Theme.Typography.footer)
            } else if didFailToSwitch {
                Label(L10n.storeSwitchFailed, systemImage: "xmark.circle.fill")
                    .font(Theme.Typography.footer)
                    .foregroundStyle(Theme.Palette.statusFailure)
                    .accessibilityIdentifier(AccessibilityID.Setup.storeError)
            }
        }
    }
}

#Preview {
    @Previewable @State var store = SecretStoreKind.sqlite
    SecretStorePicker(selection: $store, isApplying: false, didFailToSwitch: true)
        .frame(width: 460)
        .padding()
}

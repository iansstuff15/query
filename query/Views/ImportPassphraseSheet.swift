import SwiftUI

/// Asks for the passphrase of an encrypted connection export.
struct ImportPassphraseSheet: View {
    @Bindable var model: ConnectionTransferViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(L10n.importPassphraseTitle).font(.headline)
            Text(L10n.importPassphraseDetail).foregroundStyle(.secondary)
            SecureField(L10n.passphrase, text: $model.importPassphrase)
                .focused($isFocused)
                .onSubmit(model.submitImportPassphrase)
                .accessibilityIdentifier(AccessibilityID.Transfer.importPassphrase)
            TransferStatusText(status: model.status)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(role: .cancel, action: model.cancelImport) { Label(L10n.cancel, systemImage: "xmark") }
                    .keyboardShortcut(.cancelAction)
                Button(action: model.submitImportPassphrase) { Label(L10n.importAction, systemImage: "square.and.arrow.down") }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.importPassphrase.isEmpty)
                    .accessibilityIdentifier(AccessibilityID.Transfer.importSubmit)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(width: Theme.Layout.transferSheetWidth)
        .onAppear { isFocused = true }
    }
}

#Preview {
    ImportPassphraseSheet(model: ConnectionTransferViewModel(store: PreviewConnectionStore()))
}

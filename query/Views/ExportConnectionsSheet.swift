import SwiftUI
import UniformTypeIdentifiers

/// Export options: plain JSON without secrets, or passphrase-encrypted with passwords.
struct ExportConnectionsSheet: View {
    @Bindable var model: ConnectionTransferViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    Toggle(L10n.includePasswords, isOn: $model.includeSecrets)
                        .accessibilityHint(L10n.includePasswordsHint)
                        .accessibilityIdentifier(AccessibilityID.Transfer.includeSecrets)
                    if model.needsPassphrase {
                        SecureField(L10n.passphrase, text: $model.passphrase)
                            .accessibilityIdentifier(AccessibilityID.Transfer.passphrase)
                        SecureField(L10n.confirmPassphrase, text: $model.confirmation)
                            .accessibilityIdentifier(AccessibilityID.Transfer.confirmation)
                    }
                } header: {
                    Text(L10n.exportTitle)
                } footer: {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(model.needsPassphrase ? L10n.exportEncryptedFooter : L10n.exportPlainFooter)
                        TransferStatusText(status: model.status)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button(role: .cancel) { dismiss() } label: { Text(L10n.cancel) }
                    .keyboardShortcut(.cancelAction)
                Button {
                    isExporting = model.prepareExport()
                } label: {
                    Label(L10n.exportAction, systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .help(L10n.exportHint)
                .accessibilityIdentifier(AccessibilityID.Transfer.export)
            }
            .padding(Theme.Spacing.l)
        }
        .frame(width: Theme.Layout.transferSheetWidth)
        .fileExporter(
            isPresented: $isExporting,
            document: model.document,
            contentType: .json,
            defaultFilename: L10n.exportFilename
        ) { result in
            model.finishExport()
            if case .success = result { dismiss() }
        }
        .accessibilityIdentifier(AccessibilityID.Transfer.exportSheet)
    }
}

#Preview {
    ExportConnectionsSheet(model: ConnectionTransferViewModel(store: PreviewConnectionStore()))
}

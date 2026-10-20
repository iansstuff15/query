import SwiftUI

/// Inline result of an export or import.
struct TransferStatusText: View {
    let status: ConnectionTransferViewModel.Status

    var body: some View {
        Group {
            switch status {
            case .idle, .needsPassphrase: EmptyView()
            case .exported(let count): Text(L10n.exportedCount(count))
            case .imported(let count): Text(L10n.importedCount(count))
            case .wrongPassphrase: Text(L10n.wrongPassphrase)
            case .unreadable: Text(L10n.unreadableExport)
            case .passphraseTooShort: Text(L10n.passphraseTooShort)
            case .passphrasesDiffer: Text(L10n.passphrasesDiffer)
            }
        }
        .font(Theme.Typography.footer)
        .accessibilityIdentifier(AccessibilityID.Transfer.status)
    }
}

#Preview {
    TransferStatusText(status: .imported(3)).padding()
}

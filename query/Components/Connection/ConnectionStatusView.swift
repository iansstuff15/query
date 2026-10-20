import SwiftUI

/// Inline, non-modal result of Test / Connect, green on success and red on failure (the icon
/// differs too, so the state doesn't rely on color alone). Details go to the log, never to the UI.
struct ConnectionStatusView: View {
    let state: LoadState<Int>

    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView().controlSize(.small)
            case .loaded(let count):
                Label(L10n.connectionSucceeded(count), systemImage: "checkmark.circle")
                    .foregroundStyle(Theme.Palette.statusSuccess)
            case .failed:
                Label(L10n.connectionUnavailable, systemImage: "bolt.horizontal.circle")
                    .foregroundStyle(Theme.Palette.statusFailure)
            }
        }
        .font(Theme.Typography.footer)
        .accessibilityIdentifier(AccessibilityID.Connection.status)
    }
}

#Preview {
    VStack {
        ConnectionStatusView(state: .loaded(12))
        ConnectionStatusView(state: .failed(DatabaseError.connectionFailed))
    }
    .padding()
}

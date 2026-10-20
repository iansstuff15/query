import SwiftUI

/// A saved connection's reachability: a spinner while checking or connecting, then a green
/// check or a red cross (different symbols, so it doesn't rely on color alone).
struct ConnectionHealthBadge: View {
    let health: ConnectionHealth
    let isConnecting: Bool
    let identifier: String

    var body: some View {
        Group {
            if isConnecting || health == .checking {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(isConnecting ? L10n.connectionConnecting : L10n.connectionChecking)
            } else {
                switch health {
                case .reachable:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Palette.statusSuccess)
                        .help(L10n.connectionReachable)
                        .accessibilityLabel(L10n.connectionReachable)
                case .unreachable:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Palette.statusFailure)
                        .help(L10n.connectionUnreachableHelp)
                        .accessibilityLabel(L10n.connectionUnreachable)
                case .unknown, .checking:
                    EmptyView()
                }
            }
        }
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    VStack(alignment: .leading) {
        ConnectionHealthBadge(health: .checking, isConnecting: false, identifier: "preview.checking")
        ConnectionHealthBadge(health: .reachable, isConnecting: false, identifier: "preview.reachable")
        ConnectionHealthBadge(health: .unreachable, isConnecting: false, identifier: "preview.unreachable")
    }
    .padding()
}

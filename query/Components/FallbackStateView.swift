import SwiftUI

/// Neutral empty/fallback state. Used for errors too, which are never shown to the user.
struct FallbackStateView: View {
    let title: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey
    let identifier: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    FallbackStateView(title: L10n.noRows, systemImage: "line.3.horizontal.decrease.circle", message: L10n.noRowsDetail, identifier: "preview")
}

import SwiftUI

/// A thin indeterminate progress bar for the top edge of a panel, shown while it loads.
struct LoadingBar: View {
    let isActive: Bool
    let identifier: String

    var body: some View {
        if isActive {
            ProgressView()
                .progressViewStyle(.linear)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(L10n.loading)
                .accessibilityIdentifier(identifier)
        }
    }
}

#Preview {
    LoadingBar(isActive: true, identifier: "preview")
        .frame(width: 400)
        .padding()
}

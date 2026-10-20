import SwiftUI

/// Redacted, shimmering placeholder rows shown while data loads.
struct SkeletonTable: View {
    var rows = Theme.Layout.skeletonRows
    var columns = Theme.Layout.skeletonColumns
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: Theme.Spacing.xl) {
                    ForEach(0..<columns, id: \.self) { _ in
                        Text(verbatim: "placeholder value")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .redacted(reason: .placeholder)
        .shimmering()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.loading)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    SkeletonTable(identifier: "preview").frame(width: 600, height: 300)
}

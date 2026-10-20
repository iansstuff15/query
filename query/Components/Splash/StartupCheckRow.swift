import SwiftUI

/// One check on the splash screen: status glyph, name and detail.
struct StartupCheckRow: View {
    let id: StartupCheckID
    let state: StartupCheckState

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            glyph
                .frame(width: Theme.Layout.splashGlyphWidth)
                .accessibilityHidden(true)
            Text(L10n.title(for: id))
            Spacer(minLength: Theme.Spacing.s)
            if case .finished(.passed(let detail?)) = state {
                Text(verbatim: detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if case .finished(.degraded) = state {
                Text(L10n.checkUnavailable).foregroundStyle(.secondary)
            }
        }
        .font(Theme.Typography.splashCheck)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.Splash.check(id.rawValue))
    }

    @ViewBuilder
    private var glyph: some View {
        switch state {
        case .pending:
            Image(systemName: "circle").foregroundStyle(.tertiary)
        case .running:
            ProgressView().controlSize(.mini)
        case .finished(.passed):
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .finished(.degraded):
            Image(systemName: "minus.circle").foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        StartupCheckRow(id: .sqlite, state: .finished(.passed(detail: "3.46.1")))
        StartupCheckRow(id: .duckDB, state: .running)
        StartupCheckRow(id: .network, state: .finished(.degraded(reason: "offline")))
    }
    .padding()
    .frame(width: 320)
}

import SwiftUI

/// One theme in the picker: a small preview of a window in that theme (its background, primary
/// and secondary text, and an accent button), its name, and a ring when chosen.
struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: Theme.Spacing.xs) {
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(ThemeCatalog.surface(for: theme).map(AnyShapeStyle.init) ?? AnyShapeStyle(.background))
                    .overlay(alignment: .topLeading) { sample }
                    .overlay { border }
                    .environment(\.colorScheme, ThemeCatalog.appearance(for: theme) ?? colorScheme)
                    .frame(height: Theme.Layout.themeSwatchHeight)
                    .accessibilityHidden(true)
                Text(L10n.themeName(theme))
                    .font(Theme.Typography.footer)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(Theme.Spacing.xs)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(isHovered ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.clear))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(L10n.themeDescription(theme))
        .accessibilityLabel(L10n.themeName(theme))
        .accessibilityHint(L10n.themeDescription(theme))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(AccessibilityID.Setup.theme(theme.rawValue))
    }

    /// What text looks like in this theme.
    private var sample: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(L10n.themePreviewTitle)
                .font(Theme.Typography.themePreviewTitle)
                .foregroundStyle(.primary)
            Text(L10n.themePreviewDetail)
                .font(Theme.Typography.themePreviewDetail)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack(spacing: Theme.Spacing.xs) {
                Text(L10n.themePreviewButton)
                    .font(Theme.Typography.themePreviewDetail.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(ThemeCatalog.accent(for: theme), in: Capsule())
                Text(verbatim: "SELECT")
                    .font(Theme.Typography.themePreviewDetail.monospaced())
                    .foregroundStyle(ThemeCatalog.accent(for: theme))
            }
        }
        .lineLimit(1)
        .padding(Theme.Spacing.s)
    }

    private var border: some View {
        let style: AnyShapeStyle = isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator)
        return RoundedRectangle(cornerRadius: Theme.Radius.small)
            .strokeBorder(style, lineWidth: isSelected ? Theme.Layout.selectedBorderWidth : Theme.Layout.borderWidth)
    }
}

#Preview {
    HStack {
        ThemeSwatch(theme: .midnightHarbor, isSelected: true, onSelect: {})
        ThemeSwatch(theme: .cherryBlossom, isSelected: false, onSelect: {})
    }
    .frame(width: 260)
    .padding()
}

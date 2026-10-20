import SwiftUI

/// Every color theme as a grid of swatches; picking one applies it right away.
struct ThemePicker: View {
    @Binding var selection: AppTheme

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.Layout.themeSwatchMinWidth), spacing: Theme.Spacing.s)], spacing: Theme.Spacing.s) {
            ForEach(AppTheme.allCases) { theme in
                ThemeSwatch(theme: theme, isSelected: theme == selection) { selection = theme }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Setup.themes)
    }
}

#Preview {
    @Previewable @State var theme = AppTheme.glacier
    ThemePicker(selection: $theme)
        .frame(width: 520)
        .padding()
}

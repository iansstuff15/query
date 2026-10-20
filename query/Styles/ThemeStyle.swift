import SwiftUI

/// Applies the chosen `AppTheme` to a window: accent tint, appearance and background. With
/// `ENABLE_THEMES` off, every window keeps the Classic (system) look.
struct ThemeStyle: ViewModifier {
    @AppStorage(SettingsKey.theme) private var chosenTheme: AppTheme = .classic
    @Environment(\.featureFlags) private var flags

    private var theme: AppTheme { flags.themes ? chosenTheme : .classic }

    func body(content: Content) -> some View {
        content
            .tint(ThemeCatalog.accent(for: theme))
            .preferredColorScheme(ThemeCatalog.appearance(for: theme))
            .containerBackground(for: .window) {
                if let surface = ThemeCatalog.surface(for: theme) {
                    surface
                } else {
                    Rectangle().fill(.background)
                }
            }
    }
}

extension View {
    /// Tints, colors and backgrounds the window with the user's theme.
    func themed() -> some View {
        modifier(ThemeStyle())
    }
}

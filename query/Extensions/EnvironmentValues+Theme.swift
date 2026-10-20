import SwiftUI

extension EnvironmentValues {
    /// Solid background for headers, footers and toolbars inside the window: the theme's window
    /// color, so bars stay legible over content that scrolls beneath them. Set by `themed()`.
    @Entry var barBackground: Color = Theme.Palette.windowBackground
}

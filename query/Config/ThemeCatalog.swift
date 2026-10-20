import SwiftUI

/// Colors and appearance for each `AppTheme`.
enum ThemeCatalog {
    /// Buttons, selection, links and other tinted controls.
    static func accent(for theme: AppTheme) -> Color {
        switch theme {
        case .classic: .accentColor
        case .midnightHarbor: Color(.themeMidnightHarborAccent)
        case .sunlitTerracotta: Color(.themeSunlitTerracottaAccent)
        case .mintJulep: Color(.themeMintJulepAccent)
        case .auroraBorealis: Color(.themeAuroraBorealisAccent)
        case .desertDusk: Color(.themeDesertDuskAccent)
        case .lavenderFields: Color(.themeLavenderFieldsAccent)
        case .emberGlow: Color(.themeEmberGlowAccent)
        case .glacier: Color(.themeGlacierAccent)
        case .matchaLatte: Color(.themeMatchaLatteAccent)
        case .neonArcade: Color(.themeNeonArcadeAccent)
        case .cherryBlossom: Color(.themeCherryBlossomAccent)
        }
    }

    /// Window background, or `nil` to keep the system's.
    static func surface(for theme: AppTheme) -> Color? {
        switch theme {
        case .classic: nil
        case .midnightHarbor: Color(.themeMidnightHarborSurface)
        case .sunlitTerracotta: Color(.themeSunlitTerracottaSurface)
        case .mintJulep: Color(.themeMintJulepSurface)
        case .auroraBorealis: Color(.themeAuroraBorealisSurface)
        case .desertDusk: Color(.themeDesertDuskSurface)
        case .lavenderFields: Color(.themeLavenderFieldsSurface)
        case .emberGlow: Color(.themeEmberGlowSurface)
        case .glacier: Color(.themeGlacierSurface)
        case .matchaLatte: Color(.themeMatchaLatteSurface)
        case .neonArcade: Color(.themeNeonArcadeSurface)
        case .cherryBlossom: Color(.themeCherryBlossomSurface)
        }
    }

    /// Light or dark, or `nil` to follow the system setting.
    static func appearance(for theme: AppTheme) -> ColorScheme? {
        switch theme {
        case .midnightHarbor, .auroraBorealis, .emberGlow, .neonArcade: .dark
        case .sunlitTerracotta, .lavenderFields, .glacier, .cherryBlossom: .light
        case .classic, .mintJulep, .desertDusk, .matchaLatte: nil
        }
    }
}

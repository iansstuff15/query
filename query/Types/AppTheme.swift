import SwiftUI

/// A color theme: an accent color, a window background tint and an appearance. Colors come
/// from the asset catalog through `ThemeCatalog`.
nonisolated enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case classic
    case midnightHarbor
    case sunlitTerracotta
    case mintJulep
    case auroraBorealis
    case desertDusk
    case lavenderFields
    case emberGlow
    case glacier
    case matchaLatte
    case neonArcade
    case cherryBlossom

    var id: String { rawValue }
}

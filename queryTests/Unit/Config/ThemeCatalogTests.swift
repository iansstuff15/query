import SwiftUI
import Testing
@testable import query

@Suite("ThemeCatalog")
struct ThemeCatalogTests {
    @Test func offersAtLeastTenNamedThemesBesidesClassic() {
        #expect(AppTheme.allCases.filter { $0 != .classic }.count >= 10)
    }

    @Test(arguments: AppTheme.allCases.filter { $0 != .classic })
    func everyCustomThemeTintsTheWindow(theme: AppTheme) {
        #expect(ThemeCatalog.surface(for: theme) != nil)
    }

    @Test func classicKeepsTheSystemLook() {
        #expect(ThemeCatalog.surface(for: .classic) == nil)
        #expect(ThemeCatalog.appearance(for: .classic) == nil)
    }

    @Test func themesMixFixedAndSystemAppearances() {
        let appearances = AppTheme.allCases.map(ThemeCatalog.appearance(for:))
        #expect(appearances.contains(.dark))
        #expect(appearances.contains(.light))
        #expect(appearances.contains(nil))
    }
}

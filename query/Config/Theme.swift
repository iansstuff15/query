import SwiftUI

enum Theme {
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 6
        static let large: CGFloat = 12
        static let splash: CGFloat = 20
    }

    enum Layout {
        static let windowMinWidth: CGFloat = 900
        static let windowMinHeight: CGFloat = 560
        static let windowDefaultWidth: CGFloat = 1_200
        static let windowDefaultHeight: CGFloat = 760
        static let sidebarMinWidth: CGFloat = 220
        static let sidebarIdealWidth: CGFloat = 260
        static let paletteWidth: CGFloat = 560
        static let paletteHeight: CGFloat = 380
        static let filterColumnWidth: CGFloat = 170
        static let filterOperatorWidth: CGFloat = 170
        static let settingsWidth: CGFloat = 560
        static let setupWidth: CGFloat = 660
        static let setupHeight: CGFloat = 600
        static let setupStepSize: CGFloat = 22
        static let themeSwatchMinWidth: CGFloat = 132
        static let themeSwatchHeight: CGFloat = 76
        static let borderWidth: CGFloat = 1
        static let editorTabMinWidth: CGFloat = 120
        static let editorTabMaxWidth: CGFloat = 220
        static let editorTabIndicatorHeight: CGFloat = 2
        static let jumpBarDividerHeight: CGFloat = 14
        static let whatsNewWidth: CGFloat = 620
        static let whatsNewHeight: CGFloat = 580
        static let changelogIconWidth: CGFloat = 20
        static let selectedBorderWidth: CGFloat = 3
        static let engineTileMinWidth: CGFloat = 150
        static let engineTileHeight: CGFloat = 96
        static let welcomeMaxWidth: CGFloat = 960
        static let welcomeSearchWidth: CGFloat = 320
        static let recentColumnMinWidth: CGFloat = 240
        static let recentColumnIdealWidth: CGFloat = 280
        static let sqlConsoleMinWidth: CGFloat = 320
        static let sqlConsoleIdealWidth: CGFloat = 420
        static let sqlConsoleMaxWidth: CGFloat = 900
        static let sqlEditorMinHeight: CGFloat = 120
        static let sqlBatchMaxHeight: CGFloat = 220
        static let changedDotSize: CGFloat = 6
        static let usersWindowMinWidth: CGFloat = 860
        static let usersWindowMinHeight: CGFloat = 520
        static let usersWindowDefaultWidth: CGFloat = 1_040
        static let usersWindowDefaultHeight: CGFloat = 680
        static let userFormWidth: CGFloat = 340
        static let permissionColumnWidth: CGFloat = 70
        static let selectedRowBorderWidth: CGFloat = 2
        static let dataGridMinColumnWidth: Double = 72
        static let dataGridMaxColumnWidth: Double = 360
        static let connectionSheetWidth: CGFloat = 520
        static let connectionSheetMinHeight: CGFloat = 420
        static let jsonEditorHeight: CGFloat = 90
        static let transferSheetWidth: CGFloat = 440
        static let splashWidth: CGFloat = 640
        static let splashHeight: CGFloat = 400
        static let splashGlyphWidth: CGFloat = 16
        static let skeletonRows = 12
        static let skeletonColumns = 4
    }

    enum Typography {
        static let cell: Font = .body.monospaced()
        static let sql: Font = .callout.monospaced()
        static let paletteField: Font = .title3
        static let paletteDetail: Font = .caption
        static let footer: Font = .caption
        static let editorTab: Font = .callout
        static let themePreviewTitle: Font = .callout.weight(.semibold)
        static let themePreviewDetail: Font = .caption2
        static let engineIcon: Font = .largeTitle
        static let engineName: Font = .callout
        static let splashTitle: Font = .system(.largeTitle, design: .rounded).weight(.heavy)
        static let splashArtwork: Font = .system(size: 260)
        static let splashCheck: Font = .caption
    }

    enum Opacity {
        /// The accent tint behind a selected grid row.
        static let selectedRow = 0.18
    }

    enum Palette {
        static let matchHighlight = Color(.matchHighlight)
        static let rowHover = Color(.rowHover)
        static let shimmer = Color(.shimmer)
        static let rowSelection = Color.accentColor
        static let splashTop = Color(.splashTop)
        static let splashBottom = Color(.splashBottom)
        /// The system window color, behind bars when the theme has no surface of its own.
        static let windowBackground = Color(nsColor: .windowBackgroundColor)
        static let statusSuccess = Color(.statusSuccess)
        static let statusFailure = Color(.statusFailure)

        /// Category colors in What's New: features green, fixes red, the rest the theme's accent.
        static func changelog(_ category: ChangelogCategory) -> AnyShapeStyle {
            switch category {
            case .newFeatures: AnyShapeStyle(statusSuccess)
            case .bugFixes, .security: AnyShapeStyle(statusFailure)
            case .uiChanges, .improvements, .removed, .other: AnyShapeStyle(.tint)
            }
        }
    }
}

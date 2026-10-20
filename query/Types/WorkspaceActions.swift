import Foundation

/// Actions the focused workspace window exposes to menu commands.
struct WorkspaceActions {
    let openAnything: () -> Void
    let refresh: () -> Void
    let toggleFilters: () -> Void
    let focusSidebarSearch: () -> Void
    let disconnect: () -> Void
    let toggleSQLConsole: () -> Void
    let openSQLFile: () -> Void
    let goBack: () -> Void
    let goForward: () -> Void
    let closeTab: () -> Void
    let canFilter: Bool
    let canUseSQLConsole: Bool
    let canGoBack: Bool
    let canGoForward: Bool
    let hasActiveTab: Bool
}

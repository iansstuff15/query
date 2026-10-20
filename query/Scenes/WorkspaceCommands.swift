import SwiftUI

/// Database menu with keyboard shortcuts, routed to the key window.
struct WorkspaceCommands: Commands {
    @FocusedValue(\.workspaceActions) private var actions

    var body: some Commands {
        CommandMenu(L10n.databaseMenu) {
            Button { actions?.openAnything() } label: {
                Label(L10n.openAnything, systemImage: "magnifyingglass")
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(actions == nil)

            Button { actions?.focusSidebarSearch() } label: {
                Label(L10n.searchSidebar, systemImage: "sidebar.left")
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            .disabled(actions == nil)

            Button { actions?.toggleFilters() } label: {
                Label(L10n.filters, systemImage: "line.3.horizontal.decrease.circle")
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(actions?.canFilter != true)

            Button { actions?.toggleSQLConsole() } label: {
                Label(L10n.sqlConsole, systemImage: "sidebar.right")
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(actions?.canUseSQLConsole != true)

            Button { actions?.openSQLFile() } label: {
                Label(L10n.openSQLFile, systemImage: "doc.text")
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(actions?.canUseSQLConsole != true)

            Button { actions?.manageUsers() } label: {
                Label(L10n.manageUsers, systemImage: "person.2")
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
            .disabled(actions?.canManageUsers != true)

            Divider()

            Button { actions?.goBack() } label: {
                Label(L10n.goBack, systemImage: "chevron.left")
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .control])
            .disabled(actions?.canGoBack != true)

            Button { actions?.goForward() } label: {
                Label(L10n.goForward, systemImage: "chevron.right")
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .control])
            .disabled(actions?.canGoForward != true)

            Button { actions?.closeTab() } label: {
                Label(L10n.closeTab, systemImage: "xmark")
            }
            .keyboardShortcut("w", modifiers: [.command, .control])
            .disabled(actions?.hasActiveTab != true)

            Divider()

            Button { actions?.refresh() } label: {
                Label(L10n.refresh, systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(actions == nil)

            Button { actions?.disconnect() } label: {
                Label(L10n.disconnect, systemImage: "eject")
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])
            .disabled(actions == nil)
        }
    }
}

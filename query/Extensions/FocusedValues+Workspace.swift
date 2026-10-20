import SwiftUI

extension FocusedValues {
    /// Actions of the key workspace window, consumed by `WorkspaceCommands`.
    @Entry var workspaceActions: WorkspaceActions?
    /// Actions of the key welcome window, consumed by `ConnectionTransferCommands`.
    @Entry var welcomeActions: WelcomeActions?
    /// True while the SQL console's editor has focus; ⌘↩ then runs SQL instead of applying filters.
    @Entry var isEditingSQL: Bool?
    /// Opens the key window's What's New sheet, for Help ▸ What's New.
    @Entry var showWhatsNew: (() -> Void)?
}

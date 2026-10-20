import SwiftUI

/// File ▸ Import / Export Connections, routed to the key welcome window.
struct ConnectionTransferCommands: Commands {
    @FocusedValue(\.welcomeActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .importExport) {
            Button { actions?.importConnections() } label: {
                Label(L10n.importConnections, systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(actions == nil)

            Button { actions?.exportConnections() } label: {
                Label(L10n.exportConnections, systemImage: "square.and.arrow.up")
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(actions == nil)
        }
    }
}

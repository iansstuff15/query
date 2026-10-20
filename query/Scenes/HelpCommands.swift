import SwiftUI

/// Help ▸ What's New, routed to the key window.
struct HelpCommands: Commands {
    @FocusedValue(\.showWhatsNew) private var showWhatsNew

    var body: some Commands {
        CommandGroup(after: .help) {
            Button { showWhatsNew?() } label: {
                Label(L10n.whatsNewMenu, systemImage: "sparkles")
            }
            .disabled(showWhatsNew == nil)
        }
    }
}

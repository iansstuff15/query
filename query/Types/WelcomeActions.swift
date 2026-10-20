import Foundation

/// Actions the focused welcome window exposes to the File menu.
struct WelcomeActions {
    let exportConnections: () -> Void
    let importConnections: () -> Void
}

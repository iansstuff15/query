import Foundation

/// Read access to the system clipboard, so the connection sheet can pick up a copied connection string.
@MainActor
protocol ClipboardReading: AnyObject {
    /// The clipboard's text if it changed since the last call, otherwise `nil`.
    /// Also `nil` when the user has denied this app clipboard access.
    func unseenString() -> String?
}

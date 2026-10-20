import AppKit

/// The general pasteboard. Each copy is read at most once, so reopening the connection sheet
/// doesn't re-read (and re-trigger macOS's paste-permission prompt for) the same contents.
@MainActor
final class SystemClipboard: ClipboardReading {
    private let pasteboard: NSPasteboard
    private var lastChangeCount: Int?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func unseenString() -> String? {
        // `changeCount` and `accessBehavior` don't read the contents, so neither prompts the user.
        guard pasteboard.changeCount != lastChangeCount, pasteboard.accessBehavior != .alwaysDeny else { return nil }
        lastChangeCount = pasteboard.changeCount
        return pasteboard.string(forType: .string)
    }
}

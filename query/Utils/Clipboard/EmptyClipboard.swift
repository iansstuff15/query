import Foundation

/// A clipboard that is always empty, for UI tests and previews so runs never depend on what the
/// developer last copied.
@MainActor
final class EmptyClipboard: ClipboardReading {
    /// Nonisolated so it can serve as a default argument.
    nonisolated init() {}

    func unseenString() -> String? { nil }
}

@testable import query

/// Clipboard double: returns `contents` once, like `SystemClipboard` does for a single copy.
@MainActor
final class FakeClipboard: ClipboardReading {
    var contents: String?
    private(set) var reads = 0

    init(_ contents: String?) {
        self.contents = contents
    }

    func unseenString() -> String? {
        reads += 1
        defer { contents = nil }
        return contents
    }
}

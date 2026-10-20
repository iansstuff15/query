import AppKit
import Testing
@testable import query

@MainActor
@Suite("SQLTextView")
struct SQLTextViewTests {
    private func textView(_ text: String) -> SQLTextView {
        let view = SQLTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        view.string = text
        view.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        return view
    }

    @Test func completionReplacesTheWholeWordIncludingUnderscores() {
        let view = textView("SELECT * FROM order_it")
        #expect(view.rangeForUserCompletion == NSRange(location: 14, length: 8))
    }

    @Test func onlyAnAcceptedSuggestionIsInserted() {
        let view = textView("SELECT * FROM ord")
        let partial = NSRange(location: 14, length: 3)
        view.insertCompletion("orders", forPartialWordRange: partial, movement: NSTextMovement.down.rawValue, isFinal: false)
        #expect(view.string == "SELECT * FROM ord")
        view.insertCompletion("orders", forPartialWordRange: partial, movement: NSTextMovement.cancel.rawValue, isFinal: true)
        #expect(view.string == "SELECT * FROM ord")
        view.insertCompletion("orders", forPartialWordRange: partial, movement: NSTextMovement.return.rawValue, isFinal: true)
        #expect(view.string == "SELECT * FROM orders")
    }

    @Test func commandReturnRunsTheStatementAtTheCursor() throws {
        let view = textView("SELECT 1; SELECT 2\nSELECT 3")
        view.setSelectedRange(NSRange(location: 12, length: 0))
        #expect(view.statementsAtSelection.map(\.sql) == ["SELECT 2"])
        var ran: [String] = []
        view.onRunStatements = { ran = $0.map(\.sql) }
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 300, height: 100), styleMask: [], backing: .buffered, defer: true)
        window.contentView = view
        window.makeFirstResponder(view)
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: window.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36
        ))
        #expect(view.performKeyEquivalent(with: event))
        #expect(ran == ["SELECT 2"])
    }
}

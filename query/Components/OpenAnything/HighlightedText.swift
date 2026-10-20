import SwiftUI

/// Renders `text` with the characters at `offsets` emphasized — the matched letters.
struct HighlightedText: View {
    let text: String
    let offsets: [Int]

    var body: some View {
        Text(attributed)
    }

    private var attributed: AttributedString {
        let highlighted = Set(offsets)
        var result = AttributedString()
        for (offset, character) in text.enumerated() {
            var piece = AttributedString(String(character))
            if highlighted.contains(offset) {
                piece.inlinePresentationIntent = .stronglyEmphasized
                piece.foregroundColor = Theme.Palette.matchHighlight
            }
            result.append(piece)
        }
        return result
    }
}

#Preview {
    HighlightedText(text: "order_items", offsets: [0, 6]).padding()
}

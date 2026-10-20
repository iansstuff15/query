import SwiftUI

/// One Open Anything result: icon, highlighted name, schema and kind.
struct OpenAnythingRow: View {
    let match: SearchMatch
    let isHighlighted: Bool
    let identifier: String
    let onSelect: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: match.object.kind.systemImage)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            HighlightedText(text: match.object.name, offsets: match.nameOffsets)
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.s)
            Text(verbatim: match.object.schema)
                .font(Theme.Typography.paletteDetail)
                .foregroundStyle(.secondary)
            Text(L10n.title(for: match.object.kind))
                .font(Theme.Typography.paletteDetail)
                .foregroundStyle(.tertiary)
        }
        .paletteRow(isHighlighted: isHighlighted, isHovered: isHovered)
        .onHover { hovering in
            withAnimation(Motion.animation(Motion.highlight, reduceMotion: reduceMotion)) { isHovered = hovering }
        }
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isHighlighted ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(L10n.openAnythingResultHint)
        .accessibilityAction(.default, onSelect)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    VStack(spacing: 0) {
        OpenAnythingRow(
            match: SearchMatch(object: SampleCatalog.objects[3], score: 90, nameOffsets: [0, 6]),
            isHighlighted: true, identifier: "preview.0", onSelect: {}
        )
        OpenAnythingRow(
            match: SearchMatch(object: SampleCatalog.objects[4], score: 40, nameOffsets: [0]),
            isHighlighted: false, identifier: "preview.1", onSelect: {}
        )
    }
    .frame(width: Theme.Layout.paletteWidth)
    .padding()
}

import SwiftUI

/// A row of tabs, each with its icon and title (a segmented control on macOS shows only text).
/// The selected tab sits on a tinted capsule.
struct PanelTabBar<Tab: Hashable & Identifiable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let title: (Tab) -> LocalizedStringKey
    let systemImage: (Tab) -> String
    let identifier: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(tabs) { tab in
                Button { selection = tab } label: {
                    Label(title(tab), systemImage: systemImage(tab))
                        .labelStyle(.titleAndIcon)
                        .font(.callout.weight(tab == selection ? .semibold : .regular))
                        .foregroundStyle(tab == selection ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background {
                            Capsule().fill(tab == selection ? AnyShapeStyle(.tint.opacity(Theme.Opacity.selectedRow)) : AnyShapeStyle(.clear))
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == selection ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("\(identifier).\(tab.id)")
            }
        }
        .padding(Theme.Spacing.xxs)
        .background(.fill.quaternary, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    @Previewable @State var tab = SQLConsoleTab.editor
    PanelTabBar(tabs: SQLConsoleTab.allCases, selection: $tab, title: { _ in "Tab" }, systemImage: { _ in "star" }, identifier: "preview")
        .padding()
}

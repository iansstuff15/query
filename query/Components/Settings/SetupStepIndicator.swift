import SwiftUI

/// A step in the startup configuration's progress row: a numbered circle (a check once done)
/// and its name, highlighted while it's the current step.
struct SetupStepIndicator: View {
    enum State {
        case done
        case current
        case upcoming
    }

    let title: LocalizedStringKey
    let systemImage: String
    let number: Int
    let state: State
    let identifier: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(state == .upcoming ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.tint))
                if state == .done {
                    Image(systemName: "checkmark")
                        .font(Theme.Typography.footer.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Text(number, format: .number)
                        .font(Theme.Typography.footer.weight(.semibold))
                        .foregroundStyle(state == .current ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                }
            }
            .frame(width: Theme.Layout.setupStepSize, height: Theme.Layout.setupStepSize)
            .accessibilityHidden(true)
            Label(title, systemImage: systemImage)
                .labelStyle(.titleOnly)
                .font(state == .current ? .callout.weight(.semibold) : .callout)
                .foregroundStyle(state == .upcoming ? .secondary : .primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(state == .current ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    HStack {
        SetupStepIndicator(title: "Display", systemImage: "paintpalette", number: 1, state: .done, identifier: "preview.0")
        SetupStepIndicator(title: "Store", systemImage: "lock", number: 2, state: .current, identifier: "preview.1")
        SetupStepIndicator(title: "Ready", systemImage: "checkmark", number: 3, state: .upcoming, identifier: "preview.2")
    }
    .padding()
}

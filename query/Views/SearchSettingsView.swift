import SwiftUI

/// How the sidebar and Open Anything match names.
struct SearchSettingsView: View {
    @AppStorage(SettingsKey.matchingStrategy) private var matchingStrategy: MatchingStrategy = .fuzzy

    var body: some View {
        Form {
            Picker(L10n.matching, selection: $matchingStrategy) {
                ForEach(MatchingStrategy.allCases) { strategy in
                    Text(L10n.title(for: strategy)).tag(strategy)
                }
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier(AccessibilityID.Settings.matchingStrategy)
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SearchSettingsView()
}

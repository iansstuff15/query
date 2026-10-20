import SwiftUI

extension EnvironmentValues {
    /// The Info.plist feature toggles, set at the app's root so views can read them.
    @Entry var featureFlags: FeatureFlags = .current
}

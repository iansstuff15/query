import Foundation

/// The startup configuration's steps, in order.
nonisolated enum SetupStep: Int, CaseIterable, Identifiable, Sendable {
    case language
    case display
    case store
    case ready

    /// The steps to show: Language and Display only when their features are on.
    static func steps(for flags: FeatureFlags) -> [SetupStep] {
        allCases.filter { step in
            switch step {
            case .language: flags.languageSetting
            case .display: flags.themes
            case .store, .ready: true
            }
        }
    }

    var id: Int { rawValue }

    var systemImage: String {
        switch self {
        case .language: "globe"
        case .display: "paintpalette"
        case .store: "lock.rectangle.stack"
        case .ready: "checkmark.seal"
        }
    }
}

import Foundation

/// The app's display language, chosen in the startup configuration or Settings.
nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Follows the language order in System Settings.
    case system
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case japanese = "ja"

    var id: String { rawValue }

    /// The language code, or `nil` for the system's.
    var code: String? { self == .system ? nil : rawValue }

    var locale: Locale? { code.map(Locale.init(identifier:)) }

    /// The language's own name ("Español", "日本語"), so anyone can find theirs.
    var nativeName: String? {
        code.flatMap { Locale(identifier: $0).localizedString(forLanguageCode: $0) }.map(\.localizedCapitalized)
    }
}

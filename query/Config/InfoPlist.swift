import Foundation

/// Typed values from the app's Info.plist (`query-Info.plist`), with a default when a key is
/// missing or malformed and numbers clamped to a safe range.
nonisolated enum InfoPlist {
    static var main: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    static func int(_ key: String, default fallback: Int, in range: ClosedRange<Int>, info: [String: Any] = main) -> Int {
        let value: Int? = switch info[key] {
        case let number as NSNumber: number.intValue
        case let text as String: Int(text.trimmingCharacters(in: .whitespaces))
        default: nil
        }
        return min(max(value ?? fallback, range.lowerBound), range.upperBound)
    }

    /// A plist Boolean, or "YES" / "true" / "1" (and "NO" / "false" / "0") as build settings write them.
    static func bool(_ key: String, default fallback: Bool, info: [String: Any] = main) -> Bool {
        switch info[key] {
        case let flag as Bool: flag
        case let number as NSNumber: number.boolValue
        case let text as String:
            switch text.lowercased() {
            case "yes", "true", "1": true
            case "no", "false", "0": false
            default: fallback
            }
        default: fallback
        }
    }
}

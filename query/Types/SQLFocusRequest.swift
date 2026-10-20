import Foundation

/// Asks the workspace to show a result tab; `serial` makes repeated requests for the same tab
/// distinct, so each one is seen.
nonisolated struct SQLFocusRequest: Equatable, Sendable {
    let resultID: String
    let serial: Int
}

import Foundation

/// Deterministic data sets for previews and UI tests (`MOCK_DB` launch environment).
nonisolated enum StubScenario: String, CaseIterable, Sendable {
    case sample = "1"
    case empty
    case failing
}

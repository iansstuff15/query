import Foundation
import SwiftData

/// The SwiftData store for saved connections opens and can be queried.
nonisolated struct ConnectionStoreCheck: StartupCheck {
    let container: ModelContainer?
    var id: StartupCheckID { .connectionStore }

    func run() async -> StartupCheckOutcome {
        guard let container else { return .degraded(reason: "model container unavailable") }
        return await MainActor.run {
            do {
                let count = try container.mainContext.fetchCount(FetchDescriptor<SavedConnection>())
                return .passed(detail: String(count))
            } catch {
                return .degraded(reason: String(describing: error))
            }
        }
    }
}

import Foundation
import SwiftData

enum SavedConnectionQueries {
    /// Most recently used first.
    static var recent: FetchDescriptor<SavedConnection> {
        var descriptor = FetchDescriptor<SavedConnection>(sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)])
        descriptor.fetchLimit = 20
        return descriptor
    }

    static func byID(_ id: UUID) -> FetchDescriptor<SavedConnection> {
        FetchDescriptor<SavedConnection>(predicate: #Predicate { $0.id == id })
    }
}

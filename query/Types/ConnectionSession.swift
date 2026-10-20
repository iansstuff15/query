import Foundation

/// An open connection shown in a workspace window.
struct ConnectionSession: Identifiable {
    let id: UUID
    let name: String
    let engine: DatabaseEngine
    let client: any DatabaseClient
}

import Foundation

/// Static facts about an engine: form fields, defaults and accepted connection strings.
nonisolated struct EngineDescriptor: Identifiable, Hashable, Sendable {
    let engine: DatabaseEngine
    /// Product name; a brand, so not localized.
    let displayName: String
    let systemImage: String
    let family: EngineFamily
    /// Fields in form order. `.name` is implicit and always first.
    let fields: [ConnectionField]
    let defaultPort: Int?
    let defaultValues: [ConnectionField: String]
    /// Example shown as the URL field's placeholder; `nil` when the engine has no URL form.
    let urlExample: String?
    /// True when the URL is the primary input (TablePlus's Mongo/LibSQL/Elasticsearch forms).
    let isURLFirst: Bool

    var id: DatabaseEngine { engine }
    var acceptsConnectionString: Bool { urlExample != nil }

    /// Values that must be present before Test / Connect are enabled.
    var requiredFields: [ConnectionField] {
        switch family {
        case .sqlite, .duckDB: [.filePath]
        case .libSQL, .mongoDB, .elasticsearch: [.url]
        case .cloudflareD1: [.accountID, .databaseID, .apiToken]
        case .bigQuery: [.projectID]
        case .snowflake: [.account, .apiToken]
        case .dynamoDB: [.region, .accessKeyID, .secretAccessKey]
        case .oracle: [.host, .serviceName, .username]
        default: [.host]
        }
    }
}

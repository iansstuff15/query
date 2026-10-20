import Foundation

/// Every engine has a driver that can be constructed from sample settings (no connections
/// are opened; clients connect lazily).
nonisolated struct DriverRegistryCheck: StartupCheck {
    let factory: any DatabaseClientFactory
    var id: StartupCheckID { .drivers }

    static let sampleValues: [ConnectionField: String] = [
        .host: "localhost", .url: "mongodb://localhost", .filePath: "/dev/null", .accountID: "a", .databaseID: "d",
        .apiToken: "t", .projectID: "p", .endpoint: "http://localhost", .account: "a", .region: "us-east-1",
        .accessKeyID: "k", .secretAccessKey: "s", .serviceName: "FREEPDB1", .username: "u",
    ]

    func run() async -> StartupCheckOutcome {
        var missing: [DatabaseEngine] = []
        for engine in DatabaseEngine.allCases {
            var values = Self.sampleValues
            if engine == .libSQL || engine == .elasticsearch { values[.url] = "http://localhost" }
            guard let client = try? factory.makeClient(for: ConnectionDraft(engine: engine, values: values)) else {
                missing.append(engine)
                continue
            }
            await client.close()
        }
        guard missing.isEmpty else { return .degraded(reason: "no driver for \(missing.map(\.rawValue))") }
        return .passed(detail: String(DatabaseEngine.allCases.count))
    }
}

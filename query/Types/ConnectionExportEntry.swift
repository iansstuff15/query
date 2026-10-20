import Foundation

/// One connection in an export file. `values` uses `ConnectionField` raw values as keys and
/// only contains secrets when the user chose to include them.
nonisolated struct ConnectionExportEntry: Codable, Hashable, Sendable {
    var name: String
    var engine: DatabaseEngine
    var values: [String: String]

    init(name: String, engine: DatabaseEngine, values: [ConnectionField: String]) {
        self.name = name
        self.engine = engine
        self.values = Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, $0.value) })
    }

    var draft: ConnectionDraft {
        ConnectionDraft(engine: engine, values: Dictionary(uniqueKeysWithValues: values.compactMap { key, value in
            ConnectionField(rawValue: key).map { ($0, value) }
        }))
    }

    /// The same entry with secret fields removed.
    var withoutSecrets: ConnectionExportEntry {
        var copy = self
        copy.values = values.filter { ConnectionField(rawValue: $0.key)?.isSecret != true }
        return copy
    }
}

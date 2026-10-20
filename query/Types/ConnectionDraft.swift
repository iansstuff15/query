import Foundation

/// Values typed into the connection sheet (secrets included, in memory only).
nonisolated struct ConnectionDraft: Hashable, Sendable {
    var engine: DatabaseEngine
    var values: [ConnectionField: String]

    init(engine: DatabaseEngine, values: [ConnectionField: String] = [:]) {
        self.engine = engine
        self.values = values
    }

    subscript(field: ConnectionField) -> String {
        get { values[field] ?? "" }
        set { values[field] = newValue.isEmpty ? nil : newValue }
    }

    /// Trimmed value, or `nil` when empty.
    func value(_ field: ConnectionField) -> String? {
        let trimmed = (values[field] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func port(default fallback: Int?) -> Int? {
        value(.port).flatMap(Int.init) ?? fallback
    }

    var tlsMode: TLSMode {
        value(.tlsMode).flatMap(TLSMode.init(rawValue:)) ?? .prefer
    }

    var nonSecretValues: [ConnectionField: String] {
        values.filter { !$0.key.isSecret }
    }

    var secretValues: [ConnectionField: String] {
        values.filter { $0.key.isSecret }
    }
}

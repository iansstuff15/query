import Foundation
import SwiftData

/// A remembered connection. `valuesJSON` holds the non-secret fields sealed with
/// `ConnectionCipher` (AES-GCM); secrets live only in the Keychain. Name and engine stay
/// readable so the welcome screen can list connections without decrypting them.
@Model
final class SavedConnection {
    @Attribute(.unique) var id: UUID
    var name: String
    var engineRawValue: String
    var valuesJSON: Data
    var createdAt: Date
    var lastUsedAt: Date

    init(id: UUID = UUID(), name: String, engine: DatabaseEngine, sealedValues: Data, date: Date) {
        self.id = id
        self.name = name
        engineRawValue = engine.rawValue
        valuesJSON = sealedValues
        createdAt = date
        lastUsedAt = date
    }

    var engine: DatabaseEngine? { DatabaseEngine(rawValue: engineRawValue) }
}

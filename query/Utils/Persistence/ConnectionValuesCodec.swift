import Foundation

/// Encodes connection values for storage: non-secret fields only, sealed with a cipher.
nonisolated struct ConnectionValuesCodec: Sendable {
    let cipher: any ConnectionCipher

    func encode(_ values: [ConnectionField: String]) throws -> Data {
        let plain = Dictionary(uniqueKeysWithValues: values.filter { !$0.key.isSecret }.map { ($0.key.rawValue, $0.value) })
        return try cipher.seal(try JSONEncoder().encode(plain))
    }

    /// Decodes sealed data, or plaintext JSON written by builds before encryption at rest.
    func decode(_ data: Data) throws -> (values: [ConnectionField: String], wasPlaintext: Bool) {
        let isSealed = KeychainConnectionCipher.isSealed(data)
        let json = isSealed ? try cipher.open(data) : data
        let raw = try JSONDecoder().decode([String: String].self, from: json)
        let values = Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
            ConnectionField(rawValue: key).flatMap { $0.isSecret ? nil : ($0, value) }
        })
        return (values, !isSealed)
    }
}

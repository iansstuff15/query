import Foundation
import Security

/// Exchanges a Google service-account JSON key for an OAuth access token (JWT bearer flow).
actor GoogleServiceAccountTokenProvider {
    private let keyJSON: String
    private let api: any APIClient
    private let now: @Sendable () -> Date
    private var cached: (token: String, expiry: Date)?

    init(keyJSON: String, api: any APIClient, now: @escaping @Sendable () -> Date = Date.init) {
        self.keyJSON = keyJSON
        self.api = api
        self.now = now
    }

    func accessToken() async throws -> String {
        if let cached, cached.expiry > now().addingTimeInterval(60) { return cached.token }
        let key = try JSONText.object(Data(keyJSON.utf8))
        guard let email = key["client_email"] as? String, let pem = key["private_key"] as? String,
              let tokenURL = URL(string: key["token_uri"] as? String ?? "https://oauth2.googleapis.com/token") else {
            throw DatabaseError.missingConfiguration
        }
        let issued = Int(now().timeIntervalSince1970)
        let claims: [String: Any] = [
            "iss": email, "scope": "https://www.googleapis.com/auth/bigquery.readonly",
            "aud": tokenURL.absoluteString, "iat": issued, "exp": issued + 3_600,
        ]
        let assertion = try Self.signedJWT(claims: claims, privateKeyPEM: pem)
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=\(assertion)".utf8)
        let response = try await api.json(request, engine: "Google OAuth")
        guard let token = response["access_token"] as? String else { throw DatabaseError.connectionFailed }
        cached = (token, now().addingTimeInterval(TimeInterval(response["expires_in"] as? Int ?? 3_600)))
        return token
    }

    /// RS256 JWT signed with the PKCS#8 RSA key from the service-account file.
    static func signedJWT(claims: [String: Any], privateKeyPEM: String) throws -> String {
        let header = try JSONText.body(["alg": "RS256", "typ": "JWT"]).base64URLEncoded
        let payload = try JSONText.body(claims).base64URLEncoded
        let signingInput = "\(header).\(payload)"
        let key = try rsaKey(fromPKCS8PEM: privateKeyPEM)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA256, Data(signingInput.utf8) as CFData, &error) else {
            throw DatabaseError.missingConfiguration
        }
        return "\(signingInput).\((signature as Data).base64URLEncoded)"
    }

    private static func rsaKey(fromPKCS8PEM pem: String) throws -> SecKey {
        let base64 = pem.components(separatedBy: "\n").filter { !$0.hasPrefix("-----") }.joined()
        guard var der = Data(base64Encoded: base64) else { throw DatabaseError.missingConfiguration }
        // PKCS#8 wraps the PKCS#1 key SecKey expects; drop the fixed 26-byte RSA AlgorithmIdentifier header.
        if der.count > 26, der[der.startIndex + 4..<der.startIndex + 7] == Data([0x02, 0x01, 0x00]) {
            der = der.dropFirst(26)
        }
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeyClass as String: kSecAttrKeyClassPrivate]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, &error) else {
            throw DatabaseError.missingConfiguration
        }
        return key
    }
}

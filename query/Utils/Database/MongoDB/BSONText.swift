import Foundation
import MongoKitten

/// Renders BSON values as grid text (extended-JSON-like for documents and arrays).
nonisolated enum BSONText {
    static func text(_ value: Primitive?) -> String? {
        guard let value, !(value is Null) else { return nil }
        if let document = value as? Document { return JSONText.text(json(document)) }
        return JSONText.text(json(value))
    }

    static func typeName(_ value: Primitive?) -> String {
        switch value {
        case is String: "string"
        case is Int32, is Int: "int"
        case is Double: "double"
        case is Bool: "bool"
        case is ObjectId: "objectId"
        case is Date: "date"
        case let document as Document: document.isArray ? "array" : "object"
        default: ""
        }
    }

    private static func json(_ value: Primitive) -> Any {
        switch value {
        case let string as String: return string
        case let int as Int32: return Int(int)
        case let int as Int: return int
        case let double as Double: return double
        case let bool as Bool: return bool
        case let objectID as ObjectId: return objectID.hexString
        case let date as Date: return date.formatted(.iso8601)
        case is Null: return NSNull()
        case let binary as Binary: return binary.data.base64EncodedString()
        case let regex as RegularExpression: return ["$regex": regex.pattern, "$options": regex.options]
        case let document as Document:
            if document.isArray { return document.values.map(json) }
            return Dictionary(document.pairs.map { ($0.key, json($0.value)) }, uniquingKeysWith: { first, _ in first })
        default: return String(describing: value)
        }
    }
}

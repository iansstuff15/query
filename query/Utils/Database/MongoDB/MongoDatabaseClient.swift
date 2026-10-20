import Foundation
import MongoKitten
import os

/// MongoDB wire protocol via MongoKitten. Databases map to schemas and collections to objects;
/// columns are the union of top-level fields in a sample of documents.
actor MongoDatabaseClient: DatabaseClient {
    private static let sampleSize = 100

    private let connectionString: String
    private var database: MongoDatabase?

    init(connectionString: String) {
        self.connectionString = connectionString
    }

    func listObjects() async throws -> [DatabaseObject] {
        let root = try await connect()
        do {
            let listed = try? await root.pool.listDatabases()
            let databases = listed?.filter { !["admin", "config", "local"].contains($0.name) } ?? [root]
            var objects: [DatabaseObject] = []
            for database in databases {
                let collections = try await database.listCollections()
                objects += collections.map { $0.name }.filter { !$0.hasPrefix("system.") }.sorted()
                    .map { DatabaseObject(schema: database.name, name: $0, kind: .collection) }
            }
            return objects
        } catch {
            throw failure("list collections", error)
        }
    }

    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] {
        let collection = try await collection(object)
        do {
            let sample = try await collection.find().limit(Self.sampleSize).drain()
            var order = ["_id"]
            var types: [String: String] = [:]
            for document in sample {
                for key in document.keys where types[key] == nil {
                    types[key] = BSONText.typeName(document[key])
                    if key != "_id" { order.append(key) }
                }
            }
            return order.map { ColumnInfo(name: $0, dataType: types[$0] ?? "") }
        } catch {
            throw failure("sample", error)
        }
    }

    func rows(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) async throws -> QueryResult {
        let collection = try await collection(object)
        let filter = MongoFilterQuery(rules: rules, fields: columns.map(\.name)).document()
        do {
            let documents = try await collection.find(filter).limit(limit).drain()
            return QueryResult(columns: columns, values: documents.map { document in
                columns.map { BSONText.text(document[$0.name]) }
            })
        } catch {
            throw failure("find", error)
        }
    }

    nonisolated func queryPreview(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) -> String? {
        let filter = MongoFilterQuery(rules: rules, fields: columns.map(\.name)).document()
        return "db.\(object.name).find(\(BSONText.text(filter) ?? "{}")).limit(\(limit))"
    }

    func close() async {
        if let cluster = database?.pool as? MongoCluster {
            await cluster.disconnect()
        }
        database = nil
    }

    private func collection(_ object: DatabaseObject) async throws -> MongoCollection {
        let root = try await connect()
        let database = root.name == object.schema ? root : root.pool[object.schema]
        return database[object.name]
    }

    private func connect() async throws -> MongoDatabase {
        if let database { return database }
        do {
            let opened = try await MongoDatabase.connect(to: Self.withDefaultDatabase(connectionString))
            database = opened
            return opened
        } catch {
            AppLog.database.error("MongoDB connection failed: \(String(reflecting: error), privacy: .private)")
            throw DatabaseError.connectionFailed
        }
    }

    /// MongoKitten requires a database in the URI; use `admin` when none is given.
    static func withDefaultDatabase(_ uri: String) -> String {
        guard let schemeEnd = uri.range(of: "://") else { return uri }
        let afterScheme = uri[schemeEnd.upperBound...]
        let hostEnd = afterScheme.firstIndex { $0 == "/" || $0 == "?" } ?? afterScheme.endIndex
        let hosts = uri[..<hostEnd]
        let rest = uri[hostEnd...]
        if rest.hasPrefix("/"), rest.count > 1, !rest.hasPrefix("/?") { return uri }
        let query = rest.drop { $0 == "/" }
        return "\(hosts)/admin\(query)"
    }

    private func failure(_ operation: String, _ error: any Error) -> DatabaseError {
        AppLog.database.error("MongoDB \(operation, privacy: .public) failed: \(String(reflecting: error), privacy: .private)")
        return .queryFailed
    }
}

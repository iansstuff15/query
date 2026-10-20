import Foundation

/// Deterministic sample schema shared by previews, the UI-test stub and tests.
nonisolated enum SampleCatalog {
    static let objects: [DatabaseObject] = [
        DatabaseObject(schema: "analytics", name: "daily_revenue", kind: .materializedView),
        DatabaseObject(schema: "analytics", name: "page_events", kind: .partitionedTable),
        DatabaseObject(schema: "public", name: "customers", kind: .table),
        DatabaseObject(schema: "public", name: "order_items", kind: .table),
        DatabaseObject(schema: "public", name: "orders", kind: .table),
        DatabaseObject(schema: "public", name: "products", kind: .table),
        DatabaseObject(schema: "public", name: "recent_orders", kind: .view),
        DatabaseObject(schema: "sales", name: "orderLineSummary", kind: .view),
    ]

    static let customerColumns = [
        ColumnInfo(name: "id", dataType: "integer"),
        ColumnInfo(name: "email", dataType: "character varying(255)"),
        ColumnInfo(name: "full_name", dataType: "text"),
        ColumnInfo(name: "country", dataType: "text"),
        ColumnInfo(name: "created_at", dataType: "timestamp with time zone"),
    ]

    static let customerRows: [[String?]] = {
        let names = ["Ada Lovelace", "Grace Hopper", "Alan Turing", "Katherine Johnson", "Linus Torvalds",
                     "Margaret Hamilton", "Dennis Ritchie", "Barbara Liskov", "Ken Thompson", "Radia Perlman",
                     "Edsger Dijkstra", "Frances Allen"]
        let countries: [String?] = ["GB", "US", "GB", "US", "FI", "US", nil, "US", "US", "US", "NL", "US"]
        return names.enumerated().map { index, name in
            let handle = name.lowercased().replacingOccurrences(of: " ", with: ".")
            let domain = index.isMultiple(of: 3) ? "example.com" : "mail.test"
            return ["\(index + 1)", "\(handle)@\(domain)", name, countries[index], "2026-0\(index % 9 + 1)-1\(index % 10) 09:00:00+00"]
        }
    }()

    static let orderColumns = [
        ColumnInfo(name: "id", dataType: "bigint"),
        ColumnInfo(name: "customer_id", dataType: "integer"),
        ColumnInfo(name: "status", dataType: "text"),
        ColumnInfo(name: "total", dataType: "numeric(10,2)"),
    ]

    static let orderRows: [[String?]] = (1...20).map { index in
        let statuses = ["paid", "pending", "refunded", "shipped"]
        return ["\(index)", "\(index % 12 + 1)", statuses[index % statuses.count], String(format: "%.2f", Double(index) * 12.5)]
    }

    static func columns(for object: DatabaseObject) -> [ColumnInfo] {
        switch object.name {
        case "customers": customerColumns
        case "orders", "recent_orders": orderColumns
        default: [ColumnInfo(name: "id", dataType: "integer"), ColumnInfo(name: "label", dataType: "text")]
        }
    }

    static func rows(for object: DatabaseObject) -> [[String?]] {
        switch object.name {
        case "customers": customerRows
        case "orders", "recent_orders": orderRows
        default: (1...5).map { ["\($0)", "\(object.name) #\($0)"] }
        }
    }
}

@testable import query

enum Fixtures {
    static let customers = DatabaseObject(schema: "public", name: "customers", kind: .table)
    static let orders = DatabaseObject(schema: "public", name: "orders", kind: .table)
    static let orderItems = DatabaseObject(schema: "public", name: "order_items", kind: .table)
    static let lineSummary = DatabaseObject(schema: "sales", name: "orderLineSummary", kind: .view)

    static let textColumn = ColumnInfo(name: "email", dataType: "character varying(255)")
    static let intColumn = ColumnInfo(name: "id", dataType: "integer")
}

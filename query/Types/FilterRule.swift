import Foundation

/// One row in the filter bar. A `nil` column means "Any column".
nonisolated struct FilterRule: Identifiable, Hashable, Sendable {
    let id: UUID
    var column: String?
    var filterOperator: FilterOperator
    var value: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        column: String? = nil,
        filterOperator: FilterOperator = .contains,
        value: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.column = column
        self.filterOperator = filterOperator
        self.value = value
        self.isEnabled = isEnabled
    }

    /// Enabled, and has a value when the operator needs one.
    var isActive: Bool {
        isEnabled && (!filterOperator.requiresValue || !value.isEmpty)
    }
}

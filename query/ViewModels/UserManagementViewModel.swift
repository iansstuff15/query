import Foundation
import Observation
import os

/// The Users & Permissions window: the database's users, the form for a new or selected user,
/// and the selected user's table permissions (SELECT / INSERT / UPDATE / DELETE per schema and
/// table). Saving permissions grants and revokes only what changed.
@MainActor
@Observable
final class UserManagementViewModel {
    enum Selection: Hashable {
        case newUser
        case user(DatabaseUser.ID)
    }

    /// A permissions grid checkbox: on, off, or (for a schema on engines without schema grants)
    /// some tables on.
    enum CheckState: Equatable {
        case on
        case off
        case mixed
    }

    private(set) var usersState: LoadState<[DatabaseUser]> = .idle
    var selection: Selection? {
        didSet {
            guard oldValue != selection else { return }
            selectionChanged()
        }
    }
    var draft = UserDraft()
    private(set) var userSaveState: SaveState = .idle
    /// A problem with the form itself (empty or too-long name), found before contacting the server.
    private(set) var formError: UserManagementError?

    private(set) var objects: [DatabaseObject] = []
    private(set) var grantsState: LoadState<Void> = .idle
    private(set) var permissionsSaveState: SaveState = .idle
    /// Permissions as loaded, and as edited in the grid.
    private var savedGrants: [GrantTarget: Set<TablePrivilege>] = [:]
    private(set) var editedGrants: [GrantTarget: Set<TablePrivilege>] = [:]

    private let manager: (any UserManaging)?
    private let client: any DatabaseClient

    /// The user to select once the list loads (previews, README screenshots).
    private let initialUserID: DatabaseUser.ID?

    init(client: any DatabaseClient, selecting initialUserID: DatabaseUser.ID? = nil) {
        self.client = client
        self.initialUserID = initialUserID
        manager = (client as? any UserManaging).flatMap { $0.userManagement == nil ? nil : $0 }
    }

    var isSupported: Bool { manager != nil }
    var capabilities: UserManagementCapabilities { manager?.userManagement ?? .postgres }

    var users: [DatabaseUser] { usersState.value ?? [] }

    var selectedUser: DatabaseUser? {
        guard case .user(let id) = selection else { return nil }
        return users.first { $0.id == id }
    }

    var isNewUser: Bool { selection == .newUser }

    var canSaveUser: Bool {
        manager != nil && userSaveState != .saving && (isNewUser || selectedUser.map { UserDraft(user: $0) != draft } == true)
    }

    // MARK: - Loading

    func load() async {
        guard let manager else { return }
        usersState = .loading
        do {
            async let users = manager.users()
            async let catalog = client.listObjects()
            usersState = .loaded(try await users)
            objects = (try? await catalog)?.filter(\.kind.holdsRows) ?? []
            if selection == nil, let initialUserID, self.users.contains(where: { $0.id == initialUserID }) {
                selection = .user(initialUserID)
            }
        } catch {
            AppLog.database.error("Listing users failed: \(String(describing: error), privacy: .private)")
            usersState = .failed(error)
        }
    }

    // MARK: - Users

    func startNewUser() {
        selection = .newUser
    }

    func saveUser() async {
        guard let manager, canSaveUser else { return }
        formError = nil
        userSaveState = .saving
        do {
            if let user = selectedUser {
                try await manager.updateUser(user, to: draft)
            } else {
                try await manager.createUser(draft)
            }
            let saved = DatabaseUser(name: draft.trimmedName, host: capabilities.usesHosts ? draft.trimmedHost : nil, options: draft.options)
            await reloadUsers()
            selection = .user(saved.id)
            draft.password = ""
            // After the selection change, which resets the status.
            userSaveState = .saved
        } catch let error as UserManagementError {
            formError = error
            userSaveState = .idle
        } catch {
            AppLog.database.error("Saving a user failed: \(String(describing: error), privacy: .private)")
            userSaveState = .failed(Self.serverMessage(error))
        }
    }

    func deleteUser(_ user: DatabaseUser) async {
        guard let manager else { return }
        userSaveState = .saving
        do {
            try await manager.dropUser(user)
            if selectedUser == user { selection = nil }
            await reloadUsers()
            userSaveState = .idle
        } catch {
            AppLog.database.error("Dropping a user failed: \(String(describing: error), privacy: .private)")
            userSaveState = .failed(Self.serverMessage(error))
        }
    }

    // MARK: - Permissions

    /// The grid's rows: each schema, followed by its tables and views.
    var targets: [GrantTarget] {
        let schemas = Set(objects.map(\.schema)).map(GrantTarget.schema)
        let tables = objects.map { GrantTarget.table(schema: $0.schema, name: $0.name) }
        return (schemas + tables).sorted()
    }

    var hasPermissionChanges: Bool { normalized(editedGrants) != normalized(savedGrants) }

    var canEditPermissions: Bool { selectedUser != nil && grantsState.value != nil && permissionsSaveState != .saving }

    func state(of privilege: TablePrivilege, on target: GrantTarget) -> CheckState {
        if case .schema(let schema) = target, !capabilities.storesSchemaGrants {
            let tables = tables(in: schema)
            let granted = tables.filter { editedGrants[$0]?.contains(privilege) == true }.count
            guard !tables.isEmpty, granted > 0 else { return .off }
            return granted == tables.count ? .on : .mixed
        }
        return editedGrants[target]?.contains(privilege) == true ? .on : .off
    }

    /// Turns a privilege on or off. On engines without schema grants, a schema row sets every
    /// table in the schema.
    func set(_ privilege: TablePrivilege, on target: GrantTarget, granted: Bool) {
        let affected: [GrantTarget] = if case .schema(let schema) = target, !capabilities.storesSchemaGrants {
            tables(in: schema)
        } else {
            [target]
        }
        for target in affected {
            if granted {
                editedGrants[target, default: []].insert(privilege)
            } else {
                editedGrants[target]?.remove(privilege)
            }
        }
        permissionsSaveState = .idle
    }

    func revertPermissions() {
        editedGrants = savedGrants
        permissionsSaveState = .idle
    }

    func savePermissions() async {
        guard let manager, let user = selectedUser, hasPermissionChanges else { return }
        var added: [GrantTarget: Set<TablePrivilege>] = [:]
        var removed: [GrantTarget: Set<TablePrivilege>] = [:]
        for target in Set(savedGrants.keys).union(editedGrants.keys) {
            let before = savedGrants[target] ?? []
            let after = editedGrants[target] ?? []
            if !after.subtracting(before).isEmpty { added[target] = after.subtracting(before) }
            if !before.subtracting(after).isEmpty { removed[target] = before.subtracting(after) }
        }
        permissionsSaveState = .saving
        do {
            try await manager.changeGrants(of: user, granting: added, revoking: removed)
            await loadGrants(of: user)
            permissionsSaveState = .saved
        } catch {
            AppLog.database.error("Changing permissions failed: \(String(describing: error), privacy: .private)")
            permissionsSaveState = .failed(Self.serverMessage(error))
            // Some statements may have run; show what's actually granted now.
            let edited = editedGrants
            await loadGrants(of: user)
            editedGrants = edited
        }
    }

    // MARK: - Private

    private func selectionChanged() {
        userSaveState = .idle
        permissionsSaveState = .idle
        formError = nil
        savedGrants = [:]
        editedGrants = [:]
        switch selection {
        case .newUser:
            draft = UserDraft()
            grantsState = .idle
        case .user:
            guard let user = selectedUser else { return }
            draft = UserDraft(user: user)
            Task { await loadGrants(of: user) }
        case nil:
            draft = UserDraft()
            grantsState = .idle
        }
    }

    private func loadGrants(of user: DatabaseUser) async {
        guard let manager else { return }
        grantsState = .loading
        do {
            let grants = try await manager.grants(of: user)
            guard selectedUser?.id == user.id else { return }
            savedGrants = grants
            editedGrants = grants
            grantsState = .loaded(())
        } catch {
            AppLog.database.error("Reading permissions failed: \(String(describing: error), privacy: .private)")
            grantsState = .failed(error)
        }
    }

    private func reloadUsers() async {
        guard let manager else { return }
        do {
            usersState = .loaded(try await manager.users())
        } catch {
            AppLog.database.error("Listing users failed: \(String(describing: error), privacy: .private)")
        }
    }

    private func tables(in schema: String) -> [GrantTarget] {
        objects.filter { $0.schema == schema }.map { .table(schema: $0.schema, name: $0.name) }
    }

    /// Drops empty privilege sets so "nothing granted" compares equal however it's stored.
    private func normalized(_ grants: [GrantTarget: Set<TablePrivilege>]) -> [GrantTarget: Set<TablePrivilege>] {
        grants.filter { !$0.value.isEmpty }
    }

    private static func serverMessage(_ error: any Error) -> String? {
        if case DatabaseError.statementFailed(let message) = error { return message }
        return nil
    }
}

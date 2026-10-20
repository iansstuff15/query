import Testing
@testable import query

@MainActor
@Suite("UserManagementViewModel")
struct UserManagementViewModelTests {
    private let ana = DatabaseUser(name: "ana", host: nil, options: [.login])
    private let objects = [
        DatabaseObject(schema: "public", name: "customers", kind: .table),
        DatabaseObject(schema: "public", name: "orders", kind: .table),
        DatabaseObject(schema: "public", name: "customers_pkey", kind: .index),
    ]

    private func loaded(_ manager: MockUserManager) async -> UserManagementViewModel {
        let model = UserManagementViewModel(client: manager)
        await model.load()
        return model
    }

    /// Waits for the grants a selection loads in the background.
    private func select(_ user: DatabaseUser, in model: UserManagementViewModel) async {
        model.selection = .user(user.id)
        for _ in 0..<100 where model.grantsState.value == nil { await Task.yield() }
    }

    @Test func unsupportedEnginesSayHere() {
        #expect(!UserManagementViewModel(client: MockUserManager(capabilities: nil)).isSupported)
        #expect(!UserManagementViewModel(client: MockDatabaseClient()).isSupported)
    }

    @Test func loadsUsersAndTheTablesThatCanBeGranted() async {
        let model = await loaded(MockUserManager(users: [ana], objects: objects))
        #expect(model.users == [ana])
        #expect(model.targets == [.schema("public"), .table(schema: "public", name: "customers"), .table(schema: "public", name: "orders")])
    }

    @Test func aRefusedListIsAQuietFailure() async {
        let model = await loaded(MockUserManager(failure: "permission denied for table pg_authid"))
        guard case .failed = model.usersState else {
            Issue.record("Expected failed state")
            return
        }
    }

    @Test func createsAUserAndSelectsIt() async {
        let manager = MockUserManager(objects: objects)
        let model = await loaded(manager)
        model.startNewUser()
        #expect(model.isNewUser)
        model.draft.name = "bo"
        model.draft.password = "secret"
        await model.saveUser()
        #expect(await manager.storedUsers.map(\.name) == ["bo"])
        #expect(model.selection == .user("bo"))
        #expect(model.userSaveState == .saved)
        #expect(model.draft.password.isEmpty)
    }

    @Test func formErrorsStayOnTheForm() async {
        let model = await loaded(MockUserManager())
        model.startNewUser()
        await model.saveUser()
        #expect(model.formError == .emptyName)
        #expect(model.userSaveState == .idle)
    }

    @Test func serverRefusalsShowTheMessage() async {
        let manager = MockUserManager(users: [ana])
        let model = await loaded(manager)
        await select(ana, in: model)
        await manager.setFailure("must be superuser to alter superusers")
        model.draft.options.insert(.superuser)
        await model.saveUser()
        #expect(model.userSaveState == .failed("must be superuser to alter superusers"))
    }

    @Test func renamingKeepsTheUserSelectedUnderItsNewName() async {
        let manager = MockUserManager(users: [ana])
        let model = await loaded(manager)
        await select(ana, in: model)
        #expect(!model.canSaveUser) // nothing changed yet
        model.draft.name = "anna"
        await model.saveUser()
        #expect(model.selection == .user("anna"))
        #expect(model.selectedUser?.name == "anna")
    }

    @Test func deletingRemovesAndDeselects() async {
        let manager = MockUserManager(users: [ana])
        let model = await loaded(manager)
        await select(ana, in: model)
        await model.deleteUser(ana)
        #expect(model.selection == nil)
        #expect(model.users.isEmpty)
    }

    // MARK: Permissions

    @Test func postgresSchemaRowsSetEveryTableAndShowMixed() async {
        let customers = GrantTarget.table(schema: "public", name: "customers")
        let manager = MockUserManager(users: [ana], grants: [ana.id: [customers: [.select]]], objects: objects)
        let model = await loaded(manager)
        await select(ana, in: model)
        #expect(model.state(of: .select, on: .schema("public")) == .mixed)
        model.set(.select, on: .schema("public"), granted: true)
        #expect(model.state(of: .select, on: .schema("public")) == .on)
        #expect(model.state(of: .select, on: .table(schema: "public", name: "orders")) == .on)
        model.set(.update, on: customers, granted: true)
        model.set(.select, on: customers, granted: false)
        await model.savePermissions()
        let call = await manager.grantCalls.first
        #expect(call?.added == [.table(schema: "public", name: "orders"): [.select], customers: [.update]])
        #expect(call?.removed == [customers: [.select]])
        #expect(model.permissionsSaveState == .saved)
        #expect(!model.hasPermissionChanges)
    }

    @Test func mySQLSchemaRowsAreTheirOwnGrant() async {
        let manager = MockUserManager(capabilities: .mySQL, users: [DatabaseUser(name: "ana", host: "%", options: [])], objects: objects)
        let model = await loaded(manager)
        await select(DatabaseUser(name: "ana", host: "%", options: []), in: model)
        model.set(.select, on: .schema("public"), granted: true)
        #expect(model.state(of: .select, on: .schema("public")) == .on)
        #expect(model.state(of: .select, on: .table(schema: "public", name: "orders")) == .off)
        await model.savePermissions()
        #expect(await manager.grantCalls.first?.added == [.schema("public"): [.select]])
    }

    @Test func revertingDropsUnsavedPermissionChanges() async {
        let model = await loaded(MockUserManager(users: [ana], objects: objects))
        await select(ana, in: model)
        model.set(.delete, on: .table(schema: "public", name: "orders"), granted: true)
        #expect(model.hasPermissionChanges)
        model.revertPermissions()
        #expect(!model.hasPermissionChanges)
    }
}

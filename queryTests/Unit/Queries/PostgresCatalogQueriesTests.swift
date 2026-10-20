import Testing
@testable import query

@Suite("Catalog queries")
struct PostgresCatalogQueriesTests {
    @Test func postgresUsesPGCatalogAndTextColumns() {
        let sql = PostgresCatalogQueries.objects(.postgres).sql
        #expect(sql.contains("n.nspname::text, c.relname::text, c.relkind::text"))
        #expect(PostgresCatalogQueries.columns(of: Fixtures.customers, flavor: .postgres).bindings == ["public", "customers"])
    }

    @Test(arguments: [PostgresFlavor.cockroach, .redshift])
    func informationSchemaFlavors(flavor: PostgresFlavor) {
        #expect(PostgresCatalogQueries.objects(flavor).sql.contains("information_schema.tables"))
        #expect(PostgresCatalogQueries.columns(of: Fixtures.customers, flavor: flavor).sql.contains("information_schema.columns"))
    }

    @Test func verticaUsesVCatalogAndQuestionMarks() {
        #expect(PostgresCatalogQueries.objects(.vertica).sql.contains("v_catalog.tables"))
        let columns = PostgresCatalogQueries.columns(of: Fixtures.customers, flavor: .vertica)
        #expect(columns.sql.contains("table_schema = ?"))
        #expect(columns.bindings == ["public", "customers", "public", "customers"])
    }

    @Test func pseudoTypesAreNotCastable() {
        #expect(PostgresCatalogQueries.castableType("ARRAY") == "")
        #expect(PostgresCatalogQueries.castableType("USER-DEFINED") == "")
        #expect(PostgresCatalogQueries.castableType("integer") == "integer")
    }

    @Test func otherEngineCatalogsBindSchemaAndName() {
        #expect(MySQLCatalogQueries.columns(of: Fixtures.customers).bindings == ["public", "customers"])
        #expect(SQLServerCatalogQueries.columns(of: Fixtures.customers).bindings == ["[public].[customers]"])
        #expect(OracleCatalogQueries.columns(of: Fixtures.customers).sql.contains("owner = :1"))
        #expect(ClickHouseCatalogQueries.columns(of: Fixtures.customers).sql.contains("{p1:String}"))
        #expect(SQLiteCatalogQueries.columns(of: Fixtures.customers).sql.contains("pragma_table_info(?1, ?2)"))
        #expect(DuckDBCatalogQueries.objects.sql.contains("information_schema.tables"))
        #expect(SnowflakeCatalogQueries.objects.sql.contains("INFORMATION_SCHEMA"))
    }
}

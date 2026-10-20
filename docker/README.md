# Test databases

Disposable, seeded databases for every engine the app supports. Each folder has a
`compose.yaml` plus a seed file generated from one dataset by `generate_seeds.py`
(12 customers, 6 products, 20 orders, order items, a `sales` view and an `analytics` rollup).
Edit the generator, not the seed files, then run `python3 docker/generate_seeds.py`.

```sh
docker/test-db.sh list              # engines with a compose file
docker/test-db.sh up postgres       # start, wait for health, run the seed job
docker/test-db.sh down postgres     # stop and delete data
docker/run-live-tests.sh postgres   # start → run LiveEngineTests against it → stop
```

Every server engine gets two users: `query_reader` / `ReaderPass1` (read-only) and
`query_writer` / `WriterPass1` (read/write). Admin passwords are `AdminPass1` (`AdminPass1!` for SQL Server).
These are local test credentials only.

| Engine | Folder | Connection string (paste into the app) |
| --- | --- | --- |
| PostgreSQL 17 | `postgres` | `postgresql://query_reader:ReaderPass1@localhost:55432/app?sslmode=disable` |
| CockroachDB | `cockroachdb` | `postgresql://query_reader@localhost:26257/app?sslmode=disable` (insecure mode, no passwords) |
| Greenplum 7 | `greenplum` | `postgresql://query_reader@localhost:55433/postgres?sslmode=disable` (trust auth) |
| Vertica 9.1 | `vertica` | `vertica://query_reader:ReaderPass1@localhost:55434/testdb` |
| MySQL 8.4 | `mysql` | `mysql://query_reader:ReaderPass1@localhost:33306/app` |
| MariaDB 11.4 | `mariadb` | `mariadb://query_reader:ReaderPass1@localhost:33307/app` |
| SQL Server 2022 | `sqlserver` | `Server=localhost,14330;Database=app;User Id=query_reader;Password=ReaderPass1;Encrypt=False` |
| Oracle 23ai Free | `oracle` | `query_reader/ReaderPass1@localhost:15210/FREEPDB1` |
| ClickHouse 25.8 | `clickhouse` | `clickhouse://query_reader:ReaderPass1@localhost:18123/app` |
| libSQL (sqld) | `libsql` | `http://localhost:18080` |
| Cassandra 5.0 | `cassandra` | `cassandra://query_reader:ReaderPass1@localhost:19042/app` |
| Valkey 8 (Redis) | `redis` | `redis://query_reader:ReaderPass1@localhost:16379/0` |
| MongoDB 8.0 | `mongodb` | `mongodb://query_reader:ReaderPass1@localhost:27018/app?authSource=app` |
| Elasticsearch 8.15 | `elasticsearch` | `http://query_reader:ReaderPass1@localhost:19200` |
| DynamoDB Local | `dynamodb` | Region `us-east-1`, endpoint `http://localhost:18000`, any access key / secret |
| BigQuery emulator | `bigquery` | `bigquery://query-test/app?endpoint=http://localhost:19050` (no key needed) |
| SQLite | `sqlite` | `up` builds `sqlite/data/app.sqlite`; open it with **Choose…** |
| DuckDB 1.1.3 | `duckdb` | `up` builds `duckdb/data/app.duckdb`; open it with **Choose…** |

No local server exists for **Snowflake**, **Amazon Redshift** or **Cloudflare D1**. Their seed
files (`snowflake/seed.sql`, `redshift/seed.sql`, `cloudflare-d1/seed.sql`) are for a real
account (`wrangler d1 execute <db> --remote --file docker/cloudflare-d1/seed.sql` for D1). The app's
tests cover these drivers with a stubbed HTTP transport.

Notes
- SQL Server and Vertica images are amd64-only and run under Rosetta in Docker Desktop.
- Greenplum and Vertica use community images (`andruche/greenplum`, JetBrains' `datagrip/vertica`);
  official images are not published.
- DynamoDB and the BigQuery emulator have no user accounts, and SQLite / DuckDB / libSQL have no SQL users.
  Their seed files contain only the data.

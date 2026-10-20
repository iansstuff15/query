# query

A native macOS database client built with SwiftUI.

## Test databases

`docker/` holds disposable, seeded databases to test the app against. To start PostgreSQL and
MySQL together, run this from the project root (`compose.yaml` pulls in both engines):

```sh
docker compose up -d --wait         # start and seed both
docker compose down -v              # stop both and delete their data
```

Or work with one engine at a time:

```sh
docker/test-db.sh up postgres       # start and seed (same for mysql)
docker/test-db.sh down postgres     # stop and delete its data
docker/run-live-tests.sh postgres   # start, run the live tests, then stop
```

Each one is seeded with the same data:

- **Databases:** Postgres has an `app` database with `public`, `sales` and `analytics` schemas.
  MySQL has `app`, `sales` and `analytics` databases.
- **Tables:** `customers` (12 rows), `products` (6), `orders` (20) and `order_items`, plus a
  `sales` view and an `analytics` summary table.
- **Users besides the admin:**
  - `query_reader` / `ReaderPass1`: read-only
  - `query_writer` / `WriterPass1`: can also insert, update and delete in `app`

| Engine | Connection string (paste into the app) |
| --- | --- |
| PostgreSQL 17 | `postgresql://query_reader:ReaderPass1@localhost:55432/app?sslmode=disable` |
| MySQL 8.4 | `mysql://query_reader:ReaderPass1@localhost:33306/app` |

Admin logins are `postgres` and `root`, both with the password `AdminPass1`. These are local
test credentials only.

To check the setup from inside the app, use `docker/postgres/test-queries.sql` and
`docker/mysql/test-queries.sql`. They're numbered queries to run one at a time, each with its
expected result. They cover browsing, joins, views, a 10,000-row result, the reader's write
restrictions, the writer's insert/update/delete (cleaned up afterwards) and error messages.

To change the seed data, edit `docker/generate_seeds.py` and run `python3 docker/generate_seeds.py`.
Don't edit the `seed.sql` files directly, because the script overwrites them.

See [`docker/README.md`](docker/README.md) for the other engines (MariaDB, SQL Server, Oracle,
MongoDB and more).

## Continuous integration

`.github/workflows/tests.yml` runs the Unit and Integration test plans on a macOS 26 runner for
every push to `main` and every pull request, and checks that the SQL test scripts copied into
`queryTests/Fixtures` still match `docker/`. Live database tests are opt-in and don't run in CI.

To run the workflow locally with [act](https://github.com/nektos/act) (macOS jobs run on this
Mac rather than in Docker):

```sh
act -j test -P macos-26=-self-hosted
act -j fixtures
```

-- Test queries for the PostgreSQL test database (docker/postgres).
-- Run each numbered query on its own in the app; the expected result is in the comment above it.
-- Connect as query_reader unless the section says query_writer:
--   postgresql://query_reader:ReaderPass1@localhost:55432/app?sslmode=disable
--   postgresql://query_writer:WriterPass1@localhost:55432/app?sslmode=disable

-- ── 1. Connection ───────────────────────────────────────────────────────────

-- 1.1 Server, database and user. Expect: PostgreSQL 17.x | app | query_reader
SELECT version(), current_database(), current_user;

-- ── 2. Browsing schemas and tables ──────────────────────────────────────────

-- 2.1 Non-system schemas. Expect 3 rows: analytics, public, sales
SELECT schema_name FROM information_schema.schemata
WHERE schema_name NOT LIKE 'pg\_%' AND schema_name <> 'information_schema'
ORDER BY schema_name;

-- 2.2 Tables and views. Expect 5 rows: public.customers, order_items, orders, products (BASE TABLE)
--     and sales.orderLineSummary (VIEW). The materialized view is listed by 2.3.
SELECT table_schema, table_name, table_type FROM information_schema.tables
WHERE table_schema IN ('public', 'sales', 'analytics')
ORDER BY table_schema, table_name;

-- 2.3 Materialized views. Expect 1 row: analytics | daily_signups
SELECT schemaname, matviewname FROM pg_matviews ORDER BY 1, 2;

-- 2.4 Columns of customers. Expect 5 rows: id integer, email character varying, full_name text,
--     country text (nullable YES), created_at timestamp with time zone
SELECT column_name, data_type, is_nullable FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'customers'
ORDER BY ordinal_position;

-- ── 3. Row counts ───────────────────────────────────────────────────────────

-- 3.1 Expect: customers 12, products 6, orders 20, order_items 30
SELECT (SELECT count(*) FROM customers)   AS customers,
       (SELECT count(*) FROM products)    AS products,
       (SELECT count(*) FROM orders)      AS orders,
       (SELECT count(*) FROM order_items) AS order_items;

-- ── 4. Reading data ─────────────────────────────────────────────────────────

-- 4.1 All customers. Expect 12 rows; Dennis Ritchie (id 7) has a NULL country
SELECT * FROM customers ORDER BY id;

-- 4.2 Filter + sort. Expect 7 rows, all country = 'US'
SELECT id, full_name, email FROM customers WHERE country = 'US' ORDER BY full_name;

-- 4.3 NULL handling. Expect 1 row: 7 | Dennis Ritchie
SELECT id, full_name FROM customers WHERE country IS NULL;

-- 4.4 Booleans and decimals. Expect 6 rows; MN-003 and HP-006 have in_stock = false
SELECT sku, name, price, in_stock FROM products ORDER BY price DESC;

-- 4.5 Pattern match. Expect 4 rows (emails ending in @example.com)
SELECT full_name, email FROM customers WHERE email LIKE '%@example.com' ORDER BY id;

-- ── 5. Joins and aggregates ─────────────────────────────────────────────────

-- 5.1 Orders with customer names. Expect 20 rows
SELECT o.id, c.full_name, o.status, o.total, o.ordered_at
FROM orders o JOIN customers c ON c.id = o.customer_id
ORDER BY o.id;

-- 5.2 Revenue per customer. Expect 12 rows; top is Ken Thompson with 350.00
SELECT c.full_name, count(o.id) AS orders, coalesce(sum(o.total), 0) AS spent
FROM customers c LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.full_name ORDER BY spent DESC, c.full_name;

-- 5.3 Line items with product names. Expect 30 rows
SELECT oi.order_id, p.name, oi.quantity, oi.unit_price, oi.quantity * oi.unit_price AS line_total
FROM order_items oi JOIN products p ON p.id = oi.product_id
ORDER BY oi.order_id, oi.id;

-- 5.4 Best-selling products by units. Expect 6 rows; top is 27-inch Monitor with 15 units
SELECT p.name, sum(oi.quantity) AS units
FROM order_items oi JOIN products p ON p.id = oi.product_id
GROUP BY p.name ORDER BY units DESC, p.name;

-- 5.5 Window function. Expect 20 rows with a running total ending at 2625.00
SELECT id, ordered_at, total, sum(total) OVER (ORDER BY id) AS running_total
FROM orders ORDER BY id;

-- ── 6. Views across schemas ─────────────────────────────────────────────────

-- 6.1 View with a mixed-case name (needs quotes). Expect 4 rows: paid, pending, refunded, shipped (5 orders each)
SELECT * FROM sales."orderLineSummary" ORDER BY status;

-- 6.2 Materialized view. Expect 12 rows, 1 signup per day
SELECT * FROM analytics.daily_signups ORDER BY day;

-- ── 7. Larger result set (scrolling, paging, export) ────────────────────────

-- 7.1 Expect 10,000 rows
SELECT g AS n, md5(g::text) AS hash, now() - g * interval '1 minute' AS at
FROM generate_series(1, 10000) AS g;

-- ── 8. Read-only user is blocked (connected as query_reader) ────────────────

-- 8.1 Expect error: permission denied for table customers
DELETE FROM customers WHERE id = 1;

-- 8.2 Expect error: permission denied for schema public
CREATE TABLE scratch (id int);

-- ── 9. Writes (connect as query_writer) ─────────────────────────────────────

-- 9.1 Insert. Expect 1 row affected
INSERT INTO customers (id, email, full_name, country, created_at)
VALUES (100, 'test.user@example.com', 'Test User', 'CA', now());

-- 9.2 Update. Expect 1 row affected
UPDATE customers SET country = 'MX' WHERE id = 100;

-- 9.3 Check. Expect 1 row: 100 | Test User | MX
SELECT id, full_name, country FROM customers WHERE id = 100;

-- 9.4 Delete (cleans up 9.1). Expect 1 row affected
DELETE FROM customers WHERE id = 100;

-- 9.5 Views with GROUP BY are read-only. Expect error: cannot delete from view "orderLineSummary"
DELETE FROM sales."orderLineSummary";

-- ── 10. Error handling ──────────────────────────────────────────────────────

-- 10.1 Syntax error. Expect error: syntax error at or near "FORM"
SELECT * FORM customers;

-- 10.2 Missing table. Expect error: relation "missing_table" does not exist
SELECT * FROM missing_table;

-- 10.3 Division by zero. Expect error: division by zero
SELECT 1 / 0;

-- 10.4 Duplicate key (as query_writer). Expect error: duplicate key value violates unique constraint "customers_pkey"
INSERT INTO customers (id, email, full_name, created_at) VALUES (1, 'dup@example.com', 'Dup', now());

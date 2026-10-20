-- Test queries for the MySQL test database (docker/mysql).
-- Run each numbered query on its own in the app; the expected result is in the comment above it.
-- Connect as query_reader unless the section says query_writer:
--   mysql://query_reader:ReaderPass1@localhost:33306/app
--   mysql://query_writer:WriterPass1@localhost:33306/app

-- ── 1. Connection ───────────────────────────────────────────────────────────

-- 1.1 Server, database and user. Expect: 8.4.x | app | query_reader@%
SELECT VERSION(), DATABASE(), CURRENT_USER();

-- ── 2. Browsing databases and tables ────────────────────────────────────────

-- 2.1 Databases the user can see. Expect: analytics, app, information_schema, performance_schema, sales
SHOW DATABASES;

-- 2.2 Tables and views. Expect 6 rows: app.customers, order_items, orders, products (BASE TABLE),
--     analytics.daily_signups and sales.orderLineSummary (VIEW)
SELECT table_schema, table_name, table_type FROM information_schema.tables
WHERE table_schema IN ('app', 'sales', 'analytics')
ORDER BY table_schema, table_name;

-- 2.3 Columns of customers. Expect 5 rows: id int, email varchar, full_name varchar,
--     country varchar (nullable YES), created_at datetime
SELECT column_name, data_type, is_nullable FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'customers'
ORDER BY ordinal_position;

-- 2.4 Table definition. Expect 1 row with the CREATE TABLE statement
SHOW CREATE TABLE customers;

-- ── 3. Row counts ───────────────────────────────────────────────────────────

-- 3.1 Expect: customers 12, products 6, orders 20, order_items 30
SELECT (SELECT COUNT(*) FROM customers)   AS customers,
       (SELECT COUNT(*) FROM products)    AS products,
       (SELECT COUNT(*) FROM orders)      AS orders,
       (SELECT COUNT(*) FROM order_items) AS order_items;

-- ── 4. Reading data ─────────────────────────────────────────────────────────

-- 4.1 All customers. Expect 12 rows; Dennis Ritchie (id 7) has a NULL country
SELECT * FROM customers ORDER BY id;

-- 4.2 Filter + sort. Expect 7 rows, all country = 'US'
SELECT id, full_name, email FROM customers WHERE country = 'US' ORDER BY full_name;

-- 4.3 NULL handling. Expect 1 row: 7 | Dennis Ritchie
SELECT id, full_name FROM customers WHERE country IS NULL;

-- 4.4 Booleans (stored as TINYINT 0/1) and decimals. Expect 6 rows; MN-003 and HP-006 have in_stock = 0
SELECT sku, name, price, in_stock FROM products ORDER BY price DESC;

-- 4.5 Pattern match. Expect 4 rows (emails ending in @example.com)
SELECT full_name, email FROM customers WHERE email LIKE '%@example.com' ORDER BY id;

-- ── 5. Joins and aggregates ─────────────────────────────────────────────────

-- 5.1 Orders with customer names. Expect 20 rows
SELECT o.id, c.full_name, o.status, o.total, o.ordered_at
FROM orders o JOIN customers c ON c.id = o.customer_id
ORDER BY o.id;

-- 5.2 Revenue per customer. Expect 12 rows; top is Ken Thompson with 350.00
SELECT c.full_name, COUNT(o.id) AS orders, COALESCE(SUM(o.total), 0) AS spent
FROM customers c LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.full_name ORDER BY spent DESC, c.full_name;

-- 5.3 Line items with product names. Expect 30 rows
SELECT oi.order_id, p.name, oi.quantity, oi.unit_price, oi.quantity * oi.unit_price AS line_total
FROM order_items oi JOIN products p ON p.id = oi.product_id
ORDER BY oi.order_id, oi.id;

-- 5.4 Best-selling products by units. Expect 6 rows; top is 27-inch Monitor with 15 units
SELECT p.name, SUM(oi.quantity) AS units
FROM order_items oi JOIN products p ON p.id = oi.product_id
GROUP BY p.name ORDER BY units DESC, p.name;

-- 5.5 Window function. Expect 20 rows with a running total ending at 2625.00
SELECT id, ordered_at, total, SUM(total) OVER (ORDER BY id) AS running_total
FROM orders ORDER BY id;

-- ── 6. Views in other databases ─────────────────────────────────────────────

-- 6.1 Cross-database view. Expect 4 rows: paid, pending, refunded, shipped (5 orders each)
SELECT * FROM sales.orderLineSummary ORDER BY status;

-- 6.2 Expect 12 rows, 1 signup per day
SELECT * FROM analytics.daily_signups ORDER BY day;

-- ── 7. Larger result set (scrolling, paging, export) ────────────────────────

-- 7.1 Expect 10,000 rows (cross join of digits; a recursive CTE stops at 1,000 by default)
WITH d (n) AS (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
               UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9),
     seq (n) AS (SELECT a.n + b.n * 10 + c.n * 100 + e.n * 1000 + 1 FROM d a, d b, d c, d e)
SELECT n, MD5(n) AS hash, NOW() - INTERVAL n MINUTE AS at FROM seq ORDER BY n;

-- ── 8. Read-only user is blocked (connected as query_reader) ────────────────

-- 8.1 Expect error 1142: DELETE command denied to user 'query_reader'... for table 'customers'
DELETE FROM customers WHERE id = 1;

-- 8.2 Expect error 1142: CREATE command denied to user 'query_reader'... for table 'scratch'
CREATE TABLE scratch (id INT);

-- ── 9. Writes (connect as query_writer) ─────────────────────────────────────

-- 9.1 Insert. Expect 1 row affected
INSERT INTO customers (id, email, full_name, country, created_at)
VALUES (100, 'test.user@example.com', 'Test User', 'CA', NOW());

-- 9.2 Update. Expect 1 row affected
UPDATE customers SET country = 'MX' WHERE id = 100;

-- 9.3 Check. Expect 1 row: 100 | Test User | MX
SELECT id, full_name, country FROM customers WHERE id = 100;

-- 9.4 Delete (cleans up 9.1). Expect 1 row affected
DELETE FROM customers WHERE id = 100;

-- 9.5 Writer is read-only outside app. Expect error 1142: DELETE command denied ... for table 'orderLineSummary'
DELETE FROM sales.orderLineSummary;

-- ── 10. Error handling ──────────────────────────────────────────────────────

-- 10.1 Syntax error. Expect error 1064: You have an error in your SQL syntax ... near 'FORM customers'
SELECT * FORM customers;

-- 10.2 Missing table. Expect error 1146: Table 'app.missing_table' doesn't exist
SELECT * FROM missing_table;

-- 10.3 Division by zero. MySQL doesn't raise an error. Expect 1 row: NULL
SELECT 1 / 0;

-- 10.4 Duplicate key (as query_writer). Expect error 1062: Duplicate entry '1' for key 'customers.PRIMARY'
INSERT INTO customers (id, email, full_name, created_at) VALUES (1, 'dup@example.com', 'Dup', NOW());

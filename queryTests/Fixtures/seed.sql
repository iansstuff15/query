-- Disposable fixture for PostgresDatabaseClientLiveTests. Mirrors SampleCatalog.
CREATE SCHEMA IF NOT EXISTS sales;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE TABLE public.customers (
  id integer PRIMARY KEY,
  email character varying(255) NOT NULL,
  full_name text NOT NULL,
  country text,
  created_at timestamp with time zone NOT NULL
);
INSERT INTO public.customers VALUES
  (1, 'ada.lovelace@example.com', 'Ada Lovelace', 'GB', '2026-01-10 09:00:00+00'),
  (2, 'grace.hopper@mail.test', 'Grace Hopper', 'US', '2026-02-11 09:00:00+00'),
  (3, 'alan.turing@mail.test', 'Alan Turing', 'GB', '2026-03-12 09:00:00+00'),
  (4, 'katherine.johnson@example.com', 'Katherine Johnson', 'US', '2026-04-13 09:00:00+00'),
  (5, 'linus.torvalds@mail.test', 'Linus Torvalds', 'FI', '2026-05-14 09:00:00+00'),
  (6, 'margaret.hamilton@mail.test', 'Margaret Hamilton', 'US', '2026-06-15 09:00:00+00'),
  (7, 'dennis.ritchie@example.com', 'Dennis Ritchie', NULL, '2026-07-16 09:00:00+00'),
  (8, 'barbara.liskov@mail.test', 'Barbara Liskov', 'US', '2026-08-17 09:00:00+00'),
  (9, 'ken.thompson@mail.test', 'Ken Thompson', 'US', '2026-09-18 09:00:00+00'),
  (10, 'radia.perlman@example.com', 'Radia Perlman', 'US', '2026-01-19 09:00:00+00'),
  (11, 'edsger.dijkstra@mail.test', 'Edsger Dijkstra', 'NL', '2026-02-10 09:00:00+00'),
  (12, 'frances.allen@mail.test', 'Frances Allen', 'US', '2026-03-11 09:00:00+00');
CREATE TABLE public.orders (id bigint PRIMARY KEY, customer_id integer REFERENCES public.customers, status text, total numeric(10,2));
CREATE VIEW sales."orderLineSummary" AS SELECT status, sum(total) AS total FROM public.orders GROUP BY status;
CREATE MATERIALIZED VIEW analytics.daily_revenue AS SELECT created_at::date AS day, count(*) FROM public.customers GROUP BY 1;

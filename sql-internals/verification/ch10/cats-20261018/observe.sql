\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SHOW block_size;
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
SHOW default_statistics_target;
SHOW seq_page_cost;
SHOW random_page_cost;
SHOW cpu_tuple_cost;
SHOW cpu_index_tuple_cost;
SHOW cpu_operator_cost;
BEGIN;
CREATE TABLE cats AS
SELECT n AS id,
       CASE WHEN n <= 9000 THEN 'A' ELSE 'B' END AS blood_type
FROM generate_series(1, 10000) AS n;
CREATE INDEX cats_blood_type_idx ON cats(blood_type);
ANALYZE cats;
SELECT blood_type, count(*) FROM cats GROUP BY blood_type ORDER BY blood_type;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM cats WHERE blood_type = 'A';
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM cats WHERE blood_type = 'B';
\x on
SELECT most_common_vals, most_common_freqs, n_distinct
FROM pg_stats WHERE schemaname = 'public'
  AND tablename = 'cats' AND attname = 'blood_type';
\x off
SELECT relpages, reltuples FROM pg_class WHERE oid = 'cats'::regclass;
SELECT relpages * current_setting('seq_page_cost')::numeric AS page_cost,
       reltuples::numeric * current_setting('cpu_tuple_cost')::numeric AS tuple_cost,
       reltuples::numeric * current_setting('cpu_operator_cost')::numeric AS filter_cost
FROM pg_class WHERE oid = 'cats'::regclass;
SET LOCAL enable_seqscan = off;
SET LOCAL enable_bitmapscan = off;
EXPLAIN SELECT * FROM cats WHERE blood_type = 'A';
SET LOCAL enable_seqscan = on;
SET LOCAL enable_indexscan = off;
EXPLAIN SELECT * FROM cats WHERE blood_type = 'B';
SET LOCAL enable_indexscan = on;
SET LOCAL enable_bitmapscan = on;
ALTER TABLE cats ALTER COLUMN id SET STATISTICS 10;
ANALYZE cats;
\x on
SELECT n_distinct, histogram_bounds FROM pg_stats
WHERE schemaname = 'public' AND tablename = 'cats' AND attname = 'id';
\x off
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM cats WHERE id < 2500;
UPDATE cats SET blood_type = 'B' WHERE id <= 8000;
SELECT blood_type, count(*) FROM cats GROUP BY blood_type ORDER BY blood_type;
SELECT most_common_vals, most_common_freqs FROM pg_stats
WHERE schemaname='public' AND tablename='cats' AND attname='blood_type';
SELECT relpages AS stats_pages, reltuples AS stats_rows,
       pg_relation_size('cats') / current_setting('block_size')::int AS current_pages
FROM pg_class WHERE oid='cats'::regclass;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM cats WHERE blood_type = 'B';
ANALYZE cats;
SELECT most_common_vals, most_common_freqs FROM pg_stats
WHERE schemaname='public' AND tablename='cats' AND attname='blood_type';
SELECT relpages, reltuples FROM pg_class WHERE oid='cats'::regclass;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM cats WHERE blood_type = 'B';
ROLLBACK;
SELECT to_regclass('public.cats') IS NULL AS demo_removed;

\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
SHOW seq_page_cost;
SHOW random_page_cost;
SHOW cpu_tuple_cost;
SHOW cpu_index_tuple_cost;
SHOW cpu_operator_cost;
SHOW effective_cache_size;
BEGIN;
CREATE TABLE stats_demo AS
SELECT n AS id,
       CASE WHEN n <= 9000 THEN 'popular' ELSE 'rare' END AS category
FROM generate_series(1, 10000) AS n;
CREATE INDEX stats_demo_category_idx ON stats_demo(category);
ANALYZE stats_demo;
SELECT category, count(*) FROM stats_demo GROUP BY category ORDER BY category;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stats_demo WHERE category = 'popular';
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stats_demo WHERE category = 'rare';
\x on
SELECT most_common_vals, most_common_freqs, n_distinct,
       histogram_bounds IS NULL AS no_histogram
FROM pg_stats WHERE schemaname = 'public'
  AND tablename = 'stats_demo' AND attname = 'category';
\x off
SELECT relpages, reltuples FROM pg_class WHERE oid = 'stats_demo'::regclass;
SELECT relpages * current_setting('seq_page_cost')::numeric AS page_cost,
       reltuples::numeric * current_setting('cpu_tuple_cost')::numeric AS tuple_cost,
       reltuples::numeric * current_setting('cpu_operator_cost')::numeric AS filter_cost
FROM pg_class WHERE oid = 'stats_demo'::regclass;
SET LOCAL enable_seqscan = off;
SET LOCAL enable_bitmapscan = off;
EXPLAIN SELECT * FROM stats_demo WHERE category = 'popular';
SET LOCAL enable_seqscan = on;
SET LOCAL enable_indexscan = off;
EXPLAIN SELECT * FROM stats_demo WHERE category = 'rare';
SET LOCAL enable_indexscan = on;
SET LOCAL enable_bitmapscan = on;
ALTER TABLE stats_demo ALTER COLUMN id SET STATISTICS 10;
ANALYZE stats_demo;
\x on
SELECT n_distinct, histogram_bounds FROM pg_stats
WHERE schemaname = 'public' AND tablename = 'stats_demo' AND attname = 'id';
\x off
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stats_demo WHERE id < 2500;
UPDATE stats_demo SET category = 'rare' WHERE id <= 8000;
SELECT category, count(*) FROM stats_demo GROUP BY category ORDER BY category;
SELECT most_common_vals, most_common_freqs FROM pg_stats
WHERE schemaname='public' AND tablename='stats_demo' AND attname='category';
SELECT relpages AS stats_pages, reltuples AS stats_rows,
       pg_relation_size('stats_demo') / current_setting('block_size')::int AS current_pages
FROM pg_class WHERE oid='stats_demo'::regclass;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stats_demo WHERE category = 'rare';
ANALYZE stats_demo;
SELECT most_common_vals, most_common_freqs FROM pg_stats
WHERE schemaname='public' AND tablename='stats_demo' AND attname='category';
SELECT relpages, reltuples FROM pg_class WHERE oid='stats_demo'::regclass;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stats_demo WHERE category = 'rare';
ROLLBACK;
SELECT to_regclass('public.stats_demo') IS NULL AS demo_removed;
SHOW enable_seqscan;
SHOW enable_indexscan;
SHOW enable_bitmapscan;
SELECT n_distinct FROM pg_stats
WHERE schemaname='public' AND tablename='reading_records' AND attname='book_id';
EXPLAIN SELECT book_id, count(*) FROM reading_records GROUP BY book_id;
SELECT count(DISTINCT book_id) AS actual_groups FROM reading_records;

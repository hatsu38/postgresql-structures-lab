\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SHOW block_size;
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
CREATE TABLE cats WITH (autovacuum_enabled = false) AS
SELECT n AS id,
       CASE WHEN n <= 9000 THEN 'A' ELSE 'B' END AS blood_type
FROM generate_series(1, 10000) AS n;
CREATE INDEX cats_blood_type_idx ON cats(blood_type);
ANALYZE cats;
SELECT pg_relation_size('cats') / current_setting('block_size')::int AS pages, relpages, reltuples FROM pg_class WHERE oid = 'cats'::regclass;
SELECT blood_type, count(*) FROM cats GROUP BY blood_type ORDER BY blood_type;
UPDATE cats SET blood_type = 'B' WHERE id <= 8000;
SELECT pg_relation_size('cats') / current_setting('block_size')::int AS pages, relpages, reltuples FROM pg_class WHERE oid = 'cats'::regclass;
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'cats';
VACUUM (VERBOSE) cats;
SELECT pg_relation_size('cats') / current_setting('block_size')::int AS pages, relpages, reltuples FROM pg_class WHERE oid = 'cats'::regclass;
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'cats';
UPDATE cats SET blood_type = 'A' WHERE id <= 8000;
SELECT pg_relation_size('cats') / current_setting('block_size')::int AS pages, relpages, reltuples FROM pg_class WHERE oid = 'cats'::regclass;
DROP TABLE cats;

\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
BEGIN;
CREATE TABLE cats AS
SELECT n AS id,
       CASE WHEN n <= 9000 THEN 'A' ELSE 'B' END AS blood_type
FROM generate_series(1, 10000) AS n;
CREATE INDEX cats_blood_type_idx ON cats(blood_type);
ANALYZE cats;
SELECT relname, relpages, reltuples FROM pg_class WHERE relname IN ('cats', 'cats_blood_type_idx') ORDER BY relname;
SELECT correlation FROM pg_stats WHERE tablename = 'cats' AND attname = 'blood_type';
SHOW random_page_cost;
SHOW cpu_index_tuple_cost;
SET LOCAL enable_seqscan = off;
SET LOCAL enable_bitmapscan = off;
EXPLAIN SELECT * FROM cats WHERE blood_type = 'B';
EXPLAIN SELECT * FROM cats WHERE blood_type = 'A';
ROLLBACK;

\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
ANALYZE reading_records;
SELECT n_distinct FROM pg_stats WHERE schemaname='public' AND tablename='reading_records' AND attname='book_id';
EXPLAIN SELECT book_id, count(*) FROM reading_records GROUP BY book_id;
SELECT count(DISTINCT book_id) AS actual_groups FROM reading_records;

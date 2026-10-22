\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';

SELECT version(), current_database();
SELECT datcollate, datlocprovider FROM pg_database WHERE datname = current_database();
SELECT name, setting, unit FROM pg_settings
WHERE name IN ('max_parallel_workers_per_gather', 'jit', 'work_mem',
               'shared_buffers', 'block_size', 'hash_mem_multiplier',
               'default_statistics_target', 'seq_page_cost',
               'random_page_cost', 'cpu_tuple_cost', 'cpu_operator_cost',
               'effective_cache_size') ORDER BY name;
SELECT count(*) AS books FROM books;
SELECT count(*) AS reading_records FROM reading_records;
SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname = 'public' AND tablename IN ('books', 'reading_records')
ORDER BY tablename, indexname;

-- 第1章では、同じ題名検索について結果・計画・実測を順に見る。
SELECT id, title FROM books WHERE title = '実験用の本 42';
EXPLAIN
SELECT id, title FROM books WHERE title = '実験用の本 42';
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title = '実験用の本 42';

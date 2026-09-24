\set ON_ERROR_STOP on
\pset pager off
-- 観察する計画を単純にするため、接続ごとに設定します。
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
\echo === environment ===
SELECT version();
SHOW shared_buffers;
SHOW work_mem;
SHOW max_parallel_workers_per_gather;
SHOW jit;
\echo === counts ===
SELECT count(*) AS books FROM books;
SELECT count(*) AS reading_records FROM reading_records;
\echo === indexes ===
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'books' ORDER BY indexname;
\echo === result ===
SELECT id, title FROM books WHERE title = '実験用の本 42';
\echo === explain-title ===
EXPLAIN SELECT id, title FROM books WHERE title = '実験用の本 42';
\echo === analyze-title ===
EXPLAIN (ANALYZE, BUFFERS) SELECT id, title FROM books WHERE title = '実験用の本 42';
\echo === analyze-id ===
EXPLAIN (ANALYZE, BUFFERS) SELECT id, title FROM books WHERE id = 42;
\echo === analyze-missing ===
EXPLAIN (ANALYZE, BUFFERS) SELECT id, title FROM books WHERE title = '存在しない本';

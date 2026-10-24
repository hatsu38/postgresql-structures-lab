\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SELECT current_database(), datcollate, datlocprovider FROM pg_database WHERE datname = current_database();
SHOW block_size;
SHOW shared_buffers;
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
SHOW work_mem;
SHOW enable_seqscan;
SHOW enable_indexscan;
SHOW enable_bitmapscan;
SELECT indexname, indexdef FROM pg_indexes WHERE tablename IN ('books','books_observation') ORDER BY tablename,indexname;
SELECT count(*) FROM books_observation;
SELECT pg_relation_size('books_observation') / current_setting('block_size')::integer AS pages;
CREATE EXTENSION IF NOT EXISTS pg_buffercache;
SELECT buffers_skipped FROM pg_buffercache_evict_relation('books_observation');
\echo CACHE_FIRST
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books_observation WHERE title = '実験用の本 42';
\echo CACHE_SECOND
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books_observation WHERE title = '実験用の本 42';
\echo CACHE_THIRD
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books_observation WHERE title = '実験用の本 42';
CREATE INDEX reading_records_finished_at_idx ON reading_records (finished_at);
ANALYZE reading_records;
\echo DATETIME_ORDER
SELECT book_id, finished_at, ctid FROM reading_records
WHERE finished_at >= '2026-09-20 00:00:00'
  AND finished_at <  '2026-09-21 00:00:00'
ORDER BY finished_at LIMIT 8;
\echo BITMAP_DEFAULT
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= '2026-09-20 00:00:00'
  AND finished_at <  '2026-09-21 00:00:00';
BEGIN;
SET LOCAL enable_bitmapscan = off;
SET LOCAL enable_seqscan = off;
\echo INDEX_COMPARISON
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= '2026-09-20 00:00:00'
  AND finished_at <  '2026-09-21 00:00:00';
SET LOCAL enable_seqscan = on;
SET LOCAL enable_indexscan = off;
\echo SEQ_COMPARISON
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= '2026-09-20 00:00:00'
  AND finished_at <  '2026-09-21 00:00:00';
ROLLBACK;
SELECT count(*) AS matching_records,
       count(DISTINCT (ctid::text::point)[0]) AS matching_pages
FROM reading_records
WHERE finished_at >= '2026-09-20 00:00:00'
  AND finished_at <  '2026-09-21 00:00:00';
SELECT pg_relation_size('reading_records') / current_setting('block_size')::integer AS total_pages;

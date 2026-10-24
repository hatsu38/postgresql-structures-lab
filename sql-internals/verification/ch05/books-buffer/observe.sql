\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SHOW block_size;
SHOW shared_buffers;
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
CREATE INDEX books_title_idx ON books (title);
ANALYZE books;
CREATE EXTENSION pg_buffercache;
CHECKPOINT;
SELECT * FROM pg_buffercache_evict_relation('books');
SELECT * FROM pg_buffercache_evict_relation('books_title_idx');
\echo CACHE_FIRST
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title = '実験用の本 42';
\echo CACHE_SECOND
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title = '実験用の本 42';
SELECT id, title FROM books WHERE title = '実験用の本 42';

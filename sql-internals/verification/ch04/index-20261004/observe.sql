\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SELECT current_database(), datcollate, datlocprovider,
       current_setting('block_size'), current_setting('shared_buffers')
FROM pg_database WHERE datname = current_database();
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'books' ORDER BY indexname;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title = '実験用の本 42';
CREATE INDEX books_title_idx ON books (title);
ANALYZE books;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title = '実験用の本 42';
SELECT id, title FROM books WHERE title = '実験用の本 42';
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE id BETWEEN 400000 AND 400010;
SELECT id, title FROM books WHERE id BETWEEN 400000 AND 400010 ORDER BY id;
SELECT pg_size_pretty(pg_relation_size('books_title_idx')) AS index_size;
SELECT pg_relation_size('books_title_idx') AS index_bytes;
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'books' ORDER BY indexname;

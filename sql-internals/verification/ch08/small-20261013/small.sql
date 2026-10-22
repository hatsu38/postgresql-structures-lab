\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';

CREATE TEMP TABLE books_sample (id int PRIMARY KEY, title text);
CREATE TEMP TABLE records_sample (book_id int);
INSERT INTO books_sample VALUES (1, '星'), (2, '海'), (4, '森');
INSERT INTO records_sample VALUES (2), (1), (2), (4);
ANALYZE books_sample;
ANALYZE records_sample;

\echo === result ===
SELECT r.book_id, b.title
FROM records_sample AS r
JOIN books_sample AS b ON b.id = r.book_id;

\echo === default ===
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT r.book_id, b.title
FROM records_sample AS r
JOIN books_sample AS b ON b.id = r.book_id;

\echo === nestloop ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_hashjoin = off;
SET LOCAL enable_mergejoin = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT r.book_id, b.title
FROM records_sample AS r
JOIN books_sample AS b ON b.id = r.book_id;
ROLLBACK;

\echo === nestloop-index ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_hashjoin = off;
SET LOCAL enable_mergejoin = off;
SET LOCAL enable_seqscan = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT r.book_id, b.title
FROM records_sample AS r
JOIN books_sample AS b ON b.id = r.book_id;
ROLLBACK;

\echo === hashjoin ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_nestloop = off;
SET LOCAL enable_mergejoin = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT r.book_id, b.title
FROM records_sample AS r
JOIN books_sample AS b ON b.id = r.book_id;
ROLLBACK;

\echo === mergejoin ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_nestloop = off;
SET LOCAL enable_hashjoin = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT r.book_id, b.title
FROM records_sample AS r
JOIN books_sample AS b ON b.id = r.book_id;
ROLLBACK;

\echo === mergejoin-verbose ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_nestloop = off;
SET LOCAL enable_hashjoin = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF, VERBOSE)
SELECT r.book_id, b.title
FROM records_sample AS r
JOIN books_sample AS b ON b.id = r.book_id;
ROLLBACK;

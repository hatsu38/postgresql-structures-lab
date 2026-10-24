\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
SHOW hash_mem_multiplier;

\echo === latest20 ===
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.book_id, b.title, r.finished_at
FROM (
  SELECT book_id, finished_at
  FROM reading_records
  WHERE finished_at >= timestamp '2026-09-14'
    AND finished_at < timestamp '2026-09-21'
  ORDER BY finished_at DESC, book_id ASC
  LIMIT 20
) AS r
JOIN books AS b ON b.id = r.book_id
ORDER BY r.finished_at DESC, r.book_id ASC;
COPY (SELECT r.book_id, b.title, r.finished_at
FROM (
  SELECT book_id, finished_at
  FROM reading_records
  WHERE finished_at >= timestamp '2026-09-14'
    AND finished_at < timestamp '2026-09-21'
  ORDER BY finished_at DESC, book_id ASC
  LIMIT 20
) AS r
JOIN books AS b ON b.id = r.book_id
ORDER BY r.finished_at DESC, r.book_id ASC) TO '/tmp/ch07-latest.csv' WITH (FORMAT csv);

\echo === default-week ===
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.book_id, b.title, r.finished_at
FROM reading_records AS r
JOIN books AS b ON b.id = r.book_id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21';

\echo === nested ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_hashjoin = off;
SET LOCAL enable_mergejoin = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.book_id, b.title, r.finished_at
FROM reading_records AS r
JOIN books AS b ON b.id = r.book_id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21';
COPY (SELECT r.book_id, b.title, r.finished_at
FROM reading_records AS r
JOIN books AS b ON b.id = r.book_id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21') TO '/tmp/ch07-nested.csv' WITH (FORMAT csv);
ROLLBACK;

\echo === hash ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_nestloop = off;
SET LOCAL enable_mergejoin = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.book_id, b.title, r.finished_at
FROM reading_records AS r
JOIN books AS b ON b.id = r.book_id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21';
COPY (SELECT r.book_id, b.title, r.finished_at
FROM reading_records AS r
JOIN books AS b ON b.id = r.book_id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21') TO '/tmp/ch07-hash.csv' WITH (FORMAT csv);
ROLLBACK;

\echo === merge ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_nestloop = off;
SET LOCAL enable_hashjoin = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.book_id, b.title, r.finished_at
FROM reading_records AS r
JOIN books AS b ON b.id = r.book_id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21';
COPY (SELECT r.book_id, b.title, r.finished_at
FROM reading_records AS r
JOIN books AS b ON b.id = r.book_id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21') TO '/tmp/ch07-merge.csv' WITH (FORMAT csv);
ROLLBACK;

\echo === hash64 ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_nestloop = off;
SET LOCAL enable_mergejoin = off;
SET LOCAL work_mem = '64MB';
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.book_id, b.title, r.finished_at
FROM reading_records AS r
JOIN books AS b ON b.id = r.book_id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21';
COPY (SELECT r.book_id, b.title, r.finished_at
FROM reading_records AS r
JOIN books AS b ON b.id = r.book_id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21') TO '/tmp/ch07-hash64.csv' WITH (FORMAT csv);
ROLLBACK;

SHOW work_mem;
SHOW enable_nestloop;
SHOW enable_hashjoin;
SHOW enable_mergejoin;
SHOW enable_memoize;

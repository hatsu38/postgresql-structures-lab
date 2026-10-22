\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
BEGIN;
SET LOCAL work_mem = '64kB';
SET LOCAL trace_sort = on;
SET LOCAL client_min_messages = log;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at
FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC;
ROLLBACK;

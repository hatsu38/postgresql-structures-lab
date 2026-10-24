\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
CREATE INDEX reading_records_finished_at_idx ON reading_records (finished_at);
ANALYZE reading_records;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= timestamp '2026-09-20' AND finished_at < timestamp '2026-09-21';
DROP INDEX reading_records_finished_at_idx;

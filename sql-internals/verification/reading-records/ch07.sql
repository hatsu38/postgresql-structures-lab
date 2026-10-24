\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
SET work_mem = '64MB';
\echo === full ===
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC;
\echo === topn ===
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC LIMIT 20;
COPY (SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC LIMIT 20) TO '/tmp/weekly-topn.csv' CSV;
CREATE INDEX reading_records_order_idx ON reading_records (finished_at DESC, book_id ASC);
ANALYZE reading_records;
\echo === index ===
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC LIMIT 20;
COPY (SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC LIMIT 20) TO '/tmp/weekly-index.csv' CSV;
SET work_mem = '4MB';

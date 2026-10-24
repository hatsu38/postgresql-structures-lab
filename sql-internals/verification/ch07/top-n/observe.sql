\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '64MB';
SHOW work_mem;
SELECT count(*) AS week_records FROM reading_records
WHERE finished_at >= timestamp '2026-09-14' AND finished_at < timestamp '2026-09-21';
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at
FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at
FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC
LIMIT 20;
\copy (SELECT book_id, finished_at FROM reading_records WHERE finished_at >= timestamp '2026-09-14'   AND finished_at < timestamp '2026-09-21' ORDER BY finished_at DESC, book_id ASC) TO '/tmp/ch06-full.csv' CSV
\copy (SELECT book_id, finished_at FROM reading_records WHERE finished_at >= timestamp '2026-09-14'   AND finished_at < timestamp '2026-09-21' ORDER BY finished_at DESC, book_id ASC LIMIT 20) TO '/tmp/ch06-topn.csv' CSV
CREATE INDEX reading_records_order_idx
ON reading_records (finished_at DESC, book_id ASC);
ANALYZE reading_records;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at
FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC
LIMIT 20;
\copy (SELECT book_id, finished_at FROM reading_records WHERE finished_at >= timestamp '2026-09-14'   AND finished_at < timestamp '2026-09-21' ORDER BY finished_at DESC, book_id ASC LIMIT 20) TO '/tmp/ch06-index.csv' CSV
SET work_mem = '4MB';
SHOW work_mem;
SELECT tablename, indexname, indexdef FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname;

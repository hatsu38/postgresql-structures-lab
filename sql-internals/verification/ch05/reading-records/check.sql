\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
BEGIN;
-- 計画と結果を同じ設定で確認し、三方式の結果を双方向に比較する。
EXPLAIN (COSTS OFF) SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= '2026-09-20 00:00:00'
  AND finished_at <  '2026-09-21 00:00:00';
CREATE TEMP TABLE bitmap_result ON COMMIT DROP AS
SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= '2026-09-20 00:00:00'
  AND finished_at <  '2026-09-21 00:00:00';
SET LOCAL enable_bitmapscan = off;
SET LOCAL enable_seqscan = off;
EXPLAIN (COSTS OFF) SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= '2026-09-20 00:00:00'
  AND finished_at <  '2026-09-21 00:00:00';
CREATE TEMP TABLE index_result ON COMMIT DROP AS
SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= '2026-09-20 00:00:00'
  AND finished_at <  '2026-09-21 00:00:00';
SET LOCAL enable_seqscan = on;
SET LOCAL enable_indexscan = off;
EXPLAIN (COSTS OFF) SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= '2026-09-20 00:00:00'
  AND finished_at <  '2026-09-21 00:00:00';
CREATE TEMP TABLE seq_result ON COMMIT DROP AS
SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= '2026-09-20 00:00:00'
  AND finished_at <  '2026-09-21 00:00:00';
SELECT 'bitmap-index' AS comparison, count(*) AS differences FROM
((TABLE bitmap_result EXCEPT ALL TABLE index_result) UNION ALL
 (TABLE index_result EXCEPT ALL TABLE bitmap_result)) AS d
UNION ALL
SELECT 'bitmap-seq', count(*) FROM
((TABLE bitmap_result EXCEPT ALL TABLE seq_result) UNION ALL
 (TABLE seq_result EXCEPT ALL TABLE bitmap_result)) AS d;
ROLLBACK;
DROP INDEX reading_records_finished_at_idx;
DROP TABLE books_observation;
SELECT indexname, indexdef FROM pg_indexes WHERE tablename IN ('books', 'reading_records') ORDER BY tablename, indexname;
SELECT to_regclass('books_observation') IS NULL AS observation_removed;
SHOW enable_seqscan;
SHOW enable_indexscan;
SHOW enable_bitmapscan;
SHOW work_mem;
SELECT to_regclass('reading_records_finished_at_idx') IS NULL AS datetime_index_removed;

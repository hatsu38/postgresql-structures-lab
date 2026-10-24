\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
CREATE EXTENSION pg_visibility;
CREATE TABLE mvcc_reading_records WITH (autovacuum_enabled = false) AS
SELECT book_id, finished_at FROM reading_records;
CREATE INDEX mvcc_reading_records_book_time_idx
ON mvcc_reading_records (book_id, finished_at);
VACUUM (ANALYZE) mvcc_reading_records;
SELECT book_id, finished_at, ctid FROM mvcc_reading_records WHERE book_id = 42;
SELECT blkno, all_visible FROM pg_visibility_map('mvcc_reading_records')
WHERE blkno IN (4428, 10810) ORDER BY blkno;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM mvcc_reading_records WHERE book_id = 42;
BEGIN;
UPDATE mvcc_reading_records
SET finished_at = finished_at + interval '1 second' WHERE book_id = 42;
COMMIT;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM mvcc_reading_records WHERE book_id = 42;
SELECT book_id, finished_at, ctid FROM mvcc_reading_records WHERE book_id = 42;
SELECT blkno, all_visible FROM pg_visibility_map('mvcc_reading_records')
WHERE blkno IN (4428, 10810) ORDER BY blkno;
VACUUM (ANALYZE) mvcc_reading_records;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM mvcc_reading_records WHERE book_id = 42;
SELECT book_id, finished_at FROM mvcc_reading_records WHERE book_id = 42;
SELECT book_id, finished_at FROM reading_records WHERE book_id = 42;
SELECT blkno, all_visible FROM pg_visibility_map('mvcc_reading_records')
WHERE blkno IN (4428, 10810) ORDER BY blkno;

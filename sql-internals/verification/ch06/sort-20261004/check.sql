\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
BEGIN;
SET LOCAL work_mem = '64MB';
\copy (SELECT book_id, finished_at FROM reading_records WHERE finished_at >= timestamp '2026-09-14'   AND finished_at < timestamp '2026-09-21' ORDER BY finished_at DESC, book_id ASC) TO '/tmp/ch05-memory.csv' CSV
SET LOCAL work_mem = '64kB';
\copy (SELECT book_id, finished_at FROM reading_records WHERE finished_at >= timestamp '2026-09-14'   AND finished_at < timestamp '2026-09-21' ORDER BY finished_at DESC, book_id ASC) TO '/tmp/ch05-external.csv' CSV
ROLLBACK;
SHOW work_mem;
SELECT tablename, indexname, indexdef FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname;
SELECT to_regclass('books_observation') IS NULL AS observation_removed;

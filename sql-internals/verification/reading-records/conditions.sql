\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
SELECT version();
SHOW block_size;
SHOW shared_buffers;
SHOW hash_mem_multiplier;
SHOW default_statistics_target;
SHOW autovacuum;
SELECT datcollate, datctype FROM pg_database WHERE datname = current_database();
SELECT count(*) AS books FROM books;
SELECT count(*) AS records, count(DISTINCT finished_at) AS distinct_times,
       count(DISTINCT book_id) AS distinct_books, min(finished_at), max(finished_at)
FROM reading_records;
SELECT date_trunc('week', finished_at) AS week_start, count(*)
FROM reading_records GROUP BY 1 ORDER BY 1;
DO $$
BEGIN
  IF (SELECT count(*) FROM books) <> 1000000 OR
     (SELECT count(*) FROM reading_records) <> 2000000 OR
     (SELECT count(DISTINCT finished_at) FROM reading_records) <> 2000000 OR
     EXISTS (SELECT 1 FROM reading_records WHERE finished_at < timestamp '2026-08-24' OR finished_at >= timestamp '2026-09-21') OR
     (SELECT count(*) FROM (SELECT date_trunc('week', finished_at) FROM reading_records GROUP BY 1 HAVING count(*) = 500000) w) <> 4 THEN
    RAISE EXCEPTION '件数・期間・日時の一意性・週50万件のいずれかが不一致';
  END IF;
END $$;

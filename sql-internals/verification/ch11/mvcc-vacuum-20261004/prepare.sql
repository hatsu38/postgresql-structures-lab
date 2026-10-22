\set ON_ERROR_STOP on
\pset pager off
CREATE INDEX books_title_idx ON books(title);
CREATE INDEX reading_records_order_idx ON reading_records(finished_at DESC, book_id ASC);
CREATE EXTENSION pg_buffercache;
ANALYZE books;
ANALYZE reading_records;
SELECT version();
SELECT current_database(), datcollate, datctype FROM pg_database WHERE datname=current_database();
SHOW block_size;
SHOW shared_buffers;
SHOW work_mem;
SHOW hash_mem_multiplier;
SHOW default_statistics_target;
SELECT tablename, indexname, indexdef FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname;
SELECT count(*) AS records, count(DISTINCT finished_at) AS distinct_times,
       count(*) FILTER (WHERE finished_at >= timestamp '2026-09-14' AND finished_at < timestamp '2026-09-21') AS week_records
FROM reading_records;

\set ON_ERROR_STOP on
\pset pager off
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
SHOW hash_mem_multiplier;
\echo === hash-aggregate ===
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, count(*) AS read_count
FROM reading_records
GROUP BY book_id;
COPY (SELECT book_id, count(*) AS read_count FROM reading_records GROUP BY book_id) TO '/tmp/ch08-hash.csv' WITH (FORMAT csv);
\echo === group-aggregate ===
BEGIN;
SET LOCAL enable_hashagg = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, count(*) AS read_count
FROM reading_records
GROUP BY book_id;
COPY (SELECT book_id, count(*) AS read_count FROM reading_records GROUP BY book_id) TO '/tmp/ch08-group.csv' WITH (FORMAT csv);
ROLLBACK;
SHOW enable_hashagg;
SHOW work_mem;

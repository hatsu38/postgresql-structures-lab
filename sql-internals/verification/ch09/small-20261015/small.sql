\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';

CREATE TEMP TABLE records_sample (book_id int);
INSERT INTO records_sample VALUES (2), (1), (2), (4), (2);
ANALYZE records_sample;

\echo === result ===
SELECT book_id, count(*) AS read_count
FROM records_sample
GROUP BY book_id
ORDER BY book_id;

\echo === default ===
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT book_id, count(*) AS read_count
FROM records_sample
GROUP BY book_id;

\echo === hashagg ===
BEGIN;
SET LOCAL enable_sort = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT book_id, count(*) AS read_count
FROM records_sample
GROUP BY book_id;
ROLLBACK;

\echo === groupagg ===
BEGIN;
SET LOCAL enable_hashagg = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT book_id, count(*) AS read_count
FROM records_sample
GROUP BY book_id;
ROLLBACK;

\echo === groupagg-result ===
BEGIN;
SET LOCAL enable_hashagg = off;
SELECT book_id, count(*) AS read_count
FROM records_sample
GROUP BY book_id;
ROLLBACK;

\echo === sum-avg-null ===
SELECT count(*) AS records,
       count(minutes) AS measured_records,
       sum(minutes) AS total_minutes,
       avg(minutes) AS average_minutes
FROM (VALUES (10), (30), (50), (NULL::integer)) AS sessions(minutes);

SELECT count(*) AS records,
       count(minutes) AS measured_records,
       sum(minutes) AS total_minutes,
       avg(minutes) AS average_minutes
FROM (VALUES (NULL::integer)) AS sessions(minutes);

\echo === values-example ===
SELECT book_id, count(*) AS read_count
FROM (VALUES (2), (1), (2), (4), (2)) AS records(book_id)
GROUP BY book_id
ORDER BY book_id;

DROP TABLE records_sample;

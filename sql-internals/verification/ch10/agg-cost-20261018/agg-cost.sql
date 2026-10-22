\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';

CREATE TEMP TABLE records_sample (book_id int);
INSERT INTO records_sample VALUES (2), (1), (2), (4), (2);
ANALYZE records_sample;

\echo === stats ===
SELECT relpages, reltuples FROM pg_class WHERE oid = 'records_sample'::regclass;
SELECT n_distinct, most_common_vals, most_common_freqs FROM pg_stats
WHERE tablename = 'records_sample' AND attname = 'book_id';

\echo === default (costs on) ===
EXPLAIN
SELECT book_id, count(*) AS read_count
FROM records_sample
GROUP BY book_id;

\echo === groupagg (costs on) ===
BEGIN;
SET LOCAL enable_hashagg = off;
EXPLAIN
SELECT book_id, count(*) AS read_count
FROM records_sample
GROUP BY book_id;
ROLLBACK;

\echo === 200万件相当の比較は ch08-20261004 を参照 ===

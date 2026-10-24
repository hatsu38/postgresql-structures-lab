-- 第8〜10章：準備済みの通常テーブルで、結合・集計の方法を比較する。
-- 準備と実行のコマンドは、このフォルダのREADME.mdを参照。
\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SHOW work_mem;
SHOW cpu_tuple_cost;
SHOW cpu_operator_cost;
SHOW seq_page_cost;

\echo === join-result ===
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;

\echo === join-default ===
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;

\echo === nestloop ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_hashjoin = off;
SET LOCAL enable_mergejoin = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;
ROLLBACK;

\echo === nestloop-index ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_hashjoin = off;
SET LOCAL enable_mergejoin = off;
SET LOCAL enable_seqscan = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;
ROLLBACK;

\echo === hashjoin ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_nestloop = off;
SET LOCAL enable_mergejoin = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;
ROLLBACK;

\echo === mergejoin ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_nestloop = off;
SET LOCAL enable_hashjoin = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;
ROLLBACK;

\echo === mergejoin-verbose ===
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_nestloop = off;
SET LOCAL enable_hashjoin = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF, VERBOSE)
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;
ROLLBACK;

\echo === aggregate-result ===
SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample
GROUP BY book_id
ORDER BY book_id;

\echo === aggregate-default ===
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample
GROUP BY book_id;

\echo === groupagg ===
BEGIN;
SET LOCAL enable_hashagg = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample
GROUP BY book_id;

SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample
GROUP BY book_id
ORDER BY book_id;
ROLLBACK;

\echo === aggregate-stats ===
SELECT relpages, reltuples
FROM pg_class
WHERE oid = 'public.aggregate_records_sample'::regclass;
SELECT n_distinct, most_common_vals, most_common_freqs
FROM pg_stats
WHERE schemaname = 'public'
  AND tablename = 'aggregate_records_sample'
  AND attname = 'book_id';

\echo === aggregate-default-costs ===
EXPLAIN
SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample
GROUP BY book_id;

\echo === groupagg-costs ===
BEGIN;
SET LOCAL enable_hashagg = off;
EXPLAIN
SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample
GROUP BY book_id;
ROLLBACK;

\echo === sum-avg ===
SELECT count(*) AS records,
       sum(minutes) AS total_minutes,
       avg(minutes) AS average_minutes
FROM (VALUES (10), (30), (50)) AS sessions(minutes);

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

-- 第10章の補足：準備済みのcatsで、Scanのcostと範囲検索の見積もりを見る。
-- sql/cats.sqlで初期状態へ戻してから実行する。操作は最後にROLLBACKする。
\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SHOW block_size;
SHOW work_mem;
SHOW default_statistics_target;
SHOW seq_page_cost;
SHOW random_page_cost;
SHOW cpu_tuple_cost;
SHOW cpu_index_tuple_cost;
SHOW cpu_operator_cost;

BEGIN;
\echo === index-and-cost ===
SELECT relname, relpages, reltuples
FROM pg_class
WHERE oid IN ('public.cats'::regclass, 'public.cats_blood_type_idx'::regclass)
ORDER BY relname;
SELECT correlation FROM pg_stats
WHERE schemaname = 'public' AND tablename = 'cats' AND attname = 'blood_type';
SELECT relpages * current_setting('seq_page_cost')::numeric AS page_cost,
       reltuples::numeric * current_setting('cpu_tuple_cost')::numeric AS tuple_cost,
       reltuples::numeric * current_setting('cpu_operator_cost')::numeric AS filter_cost
FROM pg_class WHERE oid = 'public.cats'::regclass;

\echo === index-scan ===
SET LOCAL enable_seqscan = off;
SET LOCAL enable_bitmapscan = off;
EXPLAIN SELECT * FROM public.cats WHERE blood_type = 'B';
EXPLAIN SELECT * FROM public.cats WHERE blood_type = 'A';

\echo === seq-scan ===
SET LOCAL enable_seqscan = on;
SET LOCAL enable_indexscan = off;
EXPLAIN SELECT * FROM public.cats WHERE blood_type = 'B';
SET LOCAL enable_indexscan = on;
SET LOCAL enable_bitmapscan = on;

\echo === histogram ===
ALTER TABLE public.cats ALTER COLUMN id SET STATISTICS 10;
ANALYZE public.cats;
\x on
SELECT n_distinct, histogram_bounds FROM pg_stats
WHERE schemaname = 'public' AND tablename = 'cats' AND attname = 'id';
\x off
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM public.cats WHERE id < 2500;
ROLLBACK;

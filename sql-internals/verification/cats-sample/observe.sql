-- sql/cats.sqlで用意した通常テーブルを、新しい接続から確認する。
-- 更新を含むので、再実行する前には猫の初期化を行う。
-- 準備と実行のコマンドは、このフォルダのREADME.mdを参照。
\set ON_ERROR_STOP on
\pset pager off
SELECT version();

\echo === initial ===
SELECT blood_type, count(*) FROM public.cats GROUP BY blood_type ORDER BY blood_type;
SELECT relpages, reltuples FROM pg_class WHERE oid = 'public.cats'::regclass;
SELECT most_common_vals, most_common_freqs, n_distinct
FROM pg_stats
WHERE schemaname = 'public' AND tablename = 'cats' AND attname = 'blood_type';

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM public.cats WHERE blood_type = 'A';
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM public.cats WHERE blood_type = 'B';

\echo === update-before-analyze ===
UPDATE public.cats SET blood_type = 'B' WHERE id <= 8000;
SELECT blood_type, count(*) FROM public.cats GROUP BY blood_type ORDER BY blood_type;
SELECT most_common_vals, most_common_freqs
FROM pg_stats
WHERE schemaname = 'public' AND tablename = 'cats' AND attname = 'blood_type';
SELECT relpages AS stats_pages, reltuples AS stats_rows,
       pg_relation_size('public.cats') / current_setting('block_size')::int AS current_pages
FROM pg_class WHERE oid = 'public.cats'::regclass;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM public.cats WHERE blood_type = 'B';

\echo === after-analyze ===
ANALYZE public.cats;
SELECT most_common_vals, most_common_freqs
FROM pg_stats
WHERE schemaname = 'public' AND tablename = 'cats' AND attname = 'blood_type';
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM public.cats WHERE blood_type = 'B';

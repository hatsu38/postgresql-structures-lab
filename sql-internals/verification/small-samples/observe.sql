-- 星・海・森の通常テーブルを、新しい接続から使う実験。
-- リポジトリのルートで、サンプルを用意してからこのSQLを実行する。
-- docker compose exec -T db psql -X -1 -v ON_ERROR_STOP=1 -U postgres -d reading_map -f /lab/sql/samples.sql
-- docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -U postgres -d reading_map < sql-internals/verification/small-samples/observe.sql
-- observe.logは、準備・再接続・以下のSELECTとEXPLAINを手動実行した全出力。
-- SETやSET LOCALで計画を切り替えず、選ばれた方法と件数を見る。
\set ON_ERROR_STOP on
\pset pager off

SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id
ORDER BY r.book_id;

SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample
GROUP BY book_id
ORDER BY book_id;

EXPLAIN (ANALYZE, BUFFERS)
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;

EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample
GROUP BY book_id;

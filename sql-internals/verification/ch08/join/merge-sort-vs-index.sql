-- 第8章：Merge Joinで、本3冊の側をSortで並べるか、主キーのIndexで取り出すかの見積もりを比べる
-- 本文の「本の側を Seq Scan と Sort で並べるほうが、Index Scan より安いとプランナが見積もった」の根拠
-- 準備：sql/samples.sql で public.books_sample・public.join_records_sample を用意しておく
\set ON_ERROR_STOP on
\pset pager off
SELECT version();

BEGIN;
-- Merge Joinだけを選ばせる
SET LOCAL enable_hashjoin = off;
SET LOCAL enable_nestloop = off;

\echo === 1. そのまま：本の側も Seq Scan → Sort になる ===
EXPLAIN
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;

\echo === 2. Seq Scanを使わせない：本の側が Index Scan になる ===
-- 記録の側は Index がないので Seq Scan のまま残り、Disabled: true と出る
SET LOCAL enable_seqscan = off;
EXPLAIN
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;
ROLLBACK;

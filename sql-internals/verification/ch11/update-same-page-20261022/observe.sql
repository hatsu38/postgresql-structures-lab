\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SHOW block_size;
SHOW autovacuum;
CREATE EXTENSION IF NOT EXISTS pageinspect;
CREATE EXTENSION IF NOT EXISTS pg_visibility;

-- 更新の直後に、このテーブルを検索すると、読んだ時点でページの中身が変わる（ページの枝刈り）。
-- そのため、更新の前後のページの状態は、検索を使わず、ページの中身を直接読む関数（pageinspect の
-- page_header・heap_page_items）と可視性マップ（pg_visibility）だけで読む。更新したレコードの新しい場所は、
-- UPDATE ... RETURNING ctid で受け取る。
-- page_header の lower は、項目の番号の表の終わり、upper は、レコードを置く領域の始まり。
-- upper - lower が、そのページの空きのバイト数になる。

\echo == 1. 第11章の表11.1と同じ作り方（CREATE TABLE AS、fillfactor は既定の100）
CREATE TABLE mvcc_reading_records WITH (autovacuum_enabled = false) AS
SELECT book_id, finished_at FROM reading_records;
CREATE INDEX mvcc_reading_records_book_time_idx
ON mvcc_reading_records (book_id, finished_at);
VACUUM (ANALYZE) mvcc_reading_records;
SELECT pg_relation_size('mvcc_reading_records') / 8192 AS file_pages;

\echo -- 本42の記録の場所（元のレコード）
SELECT book_id, finished_at, ctid FROM mvcc_reading_records WHERE book_id = 42;

\echo -- 更新の前：元のレコードのページ（4428）と、新しいレコードが置かれるページ（10810）の空きと、可視性マップの印
SELECT p.page, h.lower, h.upper, h.upper - h.lower AS free_bytes,
       (SELECT v.all_visible FROM pg_visibility_map('mvcc_reading_records', p.page) v) AS all_visible
FROM (VALUES (4428), (10810)) AS p(page),
     LATERAL page_header(get_raw_page('mvcc_reading_records', p.page)) h
ORDER BY p.page;

\echo -- 日時を1秒進めて更新する（新しいレコードの場所を RETURNING で受け取る）
UPDATE mvcc_reading_records
SET finished_at = finished_at + interval '1 second' WHERE book_id = 42
RETURNING ctid AS new_ctid;

\echo -- 更新の後：新しいレコードの長さ（lp_len）と、元のレコードの項目
SELECT 'old' AS version, 4428 AS page, lp, lp_flags, lp_len, t_xmax FROM heap_page_items(get_raw_page('mvcc_reading_records', 4428)) WHERE lp = 6
UNION ALL
SELECT 'new', 10810, lp, lp_flags, lp_len, t_xmax FROM heap_page_items(get_raw_page('mvcc_reading_records', 10810)) WHERE lp = 151;

\echo -- 更新の後：2つのページの可視性マップの印
SELECT p.page, (SELECT v.all_visible FROM pg_visibility_map('mvcc_reading_records', p.page) v) AS all_visible
FROM (VALUES (4428), (10810)) AS p(page) ORDER BY p.page;

\echo == 2. 同じSQLで、fillfactor を90にして、ページに空きを残しておく
CREATE TABLE mvcc_reading_records_ff90 WITH (autovacuum_enabled = false, fillfactor = 90) AS
SELECT book_id, finished_at FROM reading_records;
CREATE INDEX mvcc_reading_records_ff90_idx
ON mvcc_reading_records_ff90 (book_id, finished_at);
VACUUM (ANALYZE) mvcc_reading_records_ff90;

\echo -- 本42の記録の場所（元のレコード）
SELECT book_id, ctid FROM mvcc_reading_records_ff90 WHERE book_id = 42;
SELECT (ctid::text::point)[0]::int AS old_page FROM mvcc_reading_records_ff90 WHERE book_id = 42 \gset

\echo -- 更新の前：元のレコードのページの空きと、可視性マップの印
SELECT :old_page AS page, h.upper - h.lower AS free_bytes,
       (SELECT v.all_visible FROM pg_visibility_map('mvcc_reading_records_ff90', :old_page) v) AS all_visible
FROM page_header(get_raw_page('mvcc_reading_records_ff90', :old_page)) h;

\echo -- 日時を1秒進めて更新する（新しいレコードの場所を RETURNING で受け取る）
UPDATE mvcc_reading_records_ff90
SET finished_at = finished_at + interval '1 second' WHERE book_id = 42
RETURNING ctid AS new_ctid;

\echo -- 更新の後：元のレコードのページの可視性マップの印
SELECT :old_page AS page,
       (SELECT v.all_visible FROM pg_visibility_map('mvcc_reading_records_ff90', :old_page) v) AS all_visible;

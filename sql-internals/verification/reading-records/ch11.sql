\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SHOW block_size;
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET check_function_bodies = off;  -- 関数が読むテーブルは、あとで作る
CREATE EXTENSION pg_visibility;
CREATE EXTENSION pageinspect;

-- 状態を調べる関数。更新の前後で、元のレコード（ページ4428の6番）と新しいレコード（ページ10810の151番）が、
-- ヒープとIndexのどうなっているかを、ページの中身（pageinspect）と可視性マップで読む。ヒープやIndexを検索で読まない。
-- lp_flags: 1=LP_NORMAL（レコードがある）、3=LP_DEAD（片付けられて、領域は空いたが、項目の番号だけ残っている）
CREATE FUNCTION heap_state(p int, l int) RETURNS TABLE (page int, lp int, lp_flags int, lp_len int, t_xmax xid, all_visible bool) AS $$
  SELECT p, i.lp, i.lp_flags, i.lp_len, i.t_xmax,
         (SELECT v.all_visible FROM pg_visibility_map('mvcc_reading_records', p) v)
  FROM heap_page_items(get_raw_page('mvcc_reading_records', p)) i WHERE i.lp = l
$$ LANGUAGE sql;
-- Indexの葉ページから、ヒープの (p,l) を指す項目を探し、dead（検索が「不要」と印を付けたもの）を返す。
CREATE FUNCTION index_state(t tid) RETURNS TABLE (index_page int, index_item_dead bool) AS $$
  SELECT s.pg, (SELECT b.dead FROM bt_page_items('mvcc_reading_records_book_time_idx', s.pg) b WHERE b.ctid = t)
  FROM generate_series(1, (pg_relation_size('mvcc_reading_records_book_time_idx') / 8192)::int - 1) AS s(pg)
  WHERE EXISTS (SELECT 1 FROM bt_page_items('mvcc_reading_records_book_time_idx', s.pg) b WHERE b.ctid = t)
$$ LANGUAGE sql;

CREATE TABLE mvcc_reading_records WITH (autovacuum_enabled = false) AS
SELECT book_id, finished_at FROM reading_records;
CREATE INDEX mvcc_reading_records_book_time_idx
ON mvcc_reading_records (book_id, finished_at);
VACUUM (ANALYZE) mvcc_reading_records;

\echo == 1. 最初のVACUUM後
SELECT book_id, finished_at, ctid FROM mvcc_reading_records WHERE book_id = 42;
SELECT * FROM heap_state(4428, 6);
SELECT * FROM index_state('(4428,6)');
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT book_id, finished_at FROM mvcc_reading_records WHERE book_id = 42;

\echo == 2. 日時を1秒進めてCOMMITした直後（検索の前）
BEGIN;
UPDATE mvcc_reading_records
SET finished_at = finished_at + interval '1 second' WHERE book_id = 42;
COMMIT;
SELECT 'old' AS version, * FROM heap_state(4428, 6);
SELECT 'new' AS version, * FROM heap_state(10810, 151);
SELECT 'old' AS version, * FROM index_state('(4428,6)');
SELECT 'new' AS version, * FROM index_state('(10810,151)');

\echo == 3. 1回目のIndex Only Scan（本の表11.1の「2」の検索）
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT book_id, finished_at FROM mvcc_reading_records WHERE book_id = 42;
SELECT 'old' AS version, * FROM heap_state(4428, 6);
SELECT 'new' AS version, * FROM heap_state(10810, 151);
SELECT 'old' AS version, * FROM index_state('(4428,6)');
SELECT 'new' AS version, * FROM index_state('(10810,151)');

\echo == 4. VACUUMの前に、もう1回同じ検索
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT book_id, finished_at FROM mvcc_reading_records WHERE book_id = 42;

\echo == 5. 再びVACUUM
VACUUM (VERBOSE) mvcc_reading_records;
SELECT 'old' AS version, * FROM heap_state(4428, 6);
SELECT 'new' AS version, * FROM heap_state(10810, 151);
SELECT 'old' AS version, * FROM index_state('(4428,6)');
SELECT 'new' AS version, * FROM index_state('(10810,151)');
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT book_id, finished_at FROM mvcc_reading_records WHERE book_id = 42;

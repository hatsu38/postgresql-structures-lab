\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SHOW block_size;
SHOW shared_buffers;
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
CREATE EXTENSION IF NOT EXISTS pageinspect;
CREATE INDEX IF NOT EXISTS books_title_idx ON books (title);
ANALYZE books;
-- Index Scan で測る。Seq Scan と Bitmap Scan は使わせない。
SET enable_seqscan = off;
SET enable_bitmapscan = off;

-- Index の段数（level=2 なら、根から葉まで3ページをたどる）
SELECT level FROM bt_metap('books_pkey');
SELECT level FROM bt_metap('books_title_idx');

-- 使うレコードの場所（ctid は（ページ番号, ページ内番号））
SELECT id, title, ctid FROM books WHERE id IN (1, 100, 101, 136, 137) ORDER BY id;
-- 題名の順に取り出すと、ページ0 → ページ7 → ページ0 の順になる
SELECT title, ctid FROM books
WHERE title IN ('実験用の本 100', '実験用の本 1000', '実験用の本 101')
ORDER BY title;

-- 各SQLを2回ずつ実行する。1回目は、そのセッションで最初に使うページやカタログを読むので、値が増えることがある。
\echo CASE_A_1ROW
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE id = 1;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE id = 1;

\echo CASE_B_100ROWS_SAME_PAGE
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE id BETWEEN 1 AND 100;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE id BETWEEN 1 AND 100;

\echo CASE_C_272ROWS_TWO_PAGES
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE id BETWEEN 1 AND 272;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE id BETWEEN 1 AND 272;

\echo CASE_D_TWO_TITLES_PAGE0_PAGE0
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books
WHERE title IN ('実験用の本 100', '実験用の本 101');
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books
WHERE title IN ('実験用の本 100', '実験用の本 101');

\echo CASE_E_THREE_TITLES_PAGE0_PAGE7_PAGE0
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books
WHERE title IN ('実験用の本 100', '実験用の本 1000', '実験用の本 101');
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books
WHERE title IN ('実験用の本 100', '実験用の本 1000', '実験用の本 101');

-- Buffers の数を、テーブルとIndexに分ける。
-- トランザクションの中で、テーブルとIndexに数えたページ数（hit と read の合計）を、実行の前後で引く。
-- プランナがIndexやテーブルを読む分を除くため、計画を作り直さない（generic plan）で、同じSQLを2回実行して、2回目の前後を引く。
SET plan_cache_mode = force_generic_plan;
PREPARE q_one(bigint) AS
SELECT id, title FROM books WHERE id = $1;
PREPARE q_pk(bigint, bigint) AS
SELECT id, title FROM books WHERE id BETWEEN $1 AND $2;
PREPARE q_in2(text, text) AS
SELECT id, title FROM books WHERE title IN ($1, $2);
PREPARE q_in3(text, text, text) AS
SELECT id, title FROM books WHERE title IN ($1, $2, $3);

\echo SPLIT_A_1ROW
BEGIN;
EXECUTE q_one(1) \g /dev/null
SELECT pg_stat_get_xact_blocks_fetched('books'::regclass) AS t0,
       pg_stat_get_xact_blocks_fetched('books_pkey'::regclass) AS i0 \gset
EXECUTE q_one(1) \g /dev/null
SELECT pg_stat_get_xact_blocks_fetched('books'::regclass) - :t0 AS table_pages,
       pg_stat_get_xact_blocks_fetched('books_pkey'::regclass) - :i0 AS index_pages;
COMMIT;

\echo SPLIT_B_100ROWS_SAME_PAGE
BEGIN;
EXECUTE q_pk(1, 100) \g /dev/null
SELECT pg_stat_get_xact_blocks_fetched('books'::regclass) AS t0,
       pg_stat_get_xact_blocks_fetched('books_pkey'::regclass) AS i0 \gset
EXECUTE q_pk(1, 100) \g /dev/null
SELECT pg_stat_get_xact_blocks_fetched('books'::regclass) - :t0 AS table_pages,
       pg_stat_get_xact_blocks_fetched('books_pkey'::regclass) - :i0 AS index_pages;
COMMIT;

\echo SPLIT_C_272ROWS_TWO_PAGES
BEGIN;
EXECUTE q_pk(1, 272) \g /dev/null
SELECT pg_stat_get_xact_blocks_fetched('books'::regclass) AS t0,
       pg_stat_get_xact_blocks_fetched('books_pkey'::regclass) AS i0 \gset
EXECUTE q_pk(1, 272) \g /dev/null
SELECT pg_stat_get_xact_blocks_fetched('books'::regclass) - :t0 AS table_pages,
       pg_stat_get_xact_blocks_fetched('books_pkey'::regclass) - :i0 AS index_pages;
COMMIT;

\echo SPLIT_D_TWO_TITLES_PAGE0_PAGE0
BEGIN;
EXECUTE q_in2('実験用の本 100', '実験用の本 101') \g /dev/null
SELECT pg_stat_get_xact_blocks_fetched('books'::regclass) AS t0,
       pg_stat_get_xact_blocks_fetched('books_title_idx'::regclass) AS i0 \gset
EXECUTE q_in2('実験用の本 100', '実験用の本 101') \g /dev/null
SELECT pg_stat_get_xact_blocks_fetched('books'::regclass) - :t0 AS table_pages,
       pg_stat_get_xact_blocks_fetched('books_title_idx'::regclass) - :i0 AS index_pages;
COMMIT;

\echo SPLIT_E_THREE_TITLES_PAGE0_PAGE7_PAGE0
BEGIN;
EXECUTE q_in3('実験用の本 100', '実験用の本 1000', '実験用の本 101') \g /dev/null
SELECT pg_stat_get_xact_blocks_fetched('books'::regclass) AS t0,
       pg_stat_get_xact_blocks_fetched('books_title_idx'::regclass) AS i0 \gset
EXECUTE q_in3('実験用の本 100', '実験用の本 1000', '実験用の本 101') \g /dev/null
SELECT pg_stat_get_xact_blocks_fetched('books'::regclass) - :t0 AS table_pages,
       pg_stat_get_xact_blocks_fetched('books_title_idx'::regclass) - :i0 AS index_pages;
COMMIT;

-- 比べるために、Seq Scan も測る。1ページに136件ずつ入っているが、数えるのはページ数の分だけ。
RESET plan_cache_mode;
SET enable_seqscan = on;
SET enable_indexscan = off;
SELECT pg_relation_size('books') / 8192 AS table_pages, count(*) AS records FROM books;
\echo CASE_F_SEQ_SCAN
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM books;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM books;

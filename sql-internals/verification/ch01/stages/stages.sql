-- 第1章「SQLを実行したとき、PostgreSQLの中では何が起きているのか」の観察。
-- 各段階で止まるエラーと、ビューの展開、計画と実行の時間を確かめる。
\set ON_ERROR_STOP off
-- 既存の第1章の実測（ch02-explain/observe.sql）と同じ条件にそろえる
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
\echo === 1. 正しいSQL（結果）
SELECT id, title FROM books WHERE title = '実験用の本 42';
\echo === 2. パーサで止まる（FROM を FORM と打つ）
SELECT id, title FORM books WHERE title = '実験用の本 42';
\echo === 2b. FORM は列の別名として読まれる（books が続いたので止まった）
SELECT id, title FORM FROM books WHERE id = 42;
\echo === 3. アナライザで止まる（列名の誤り）
SELECT id, titel FROM books WHERE title = '実験用の本 42';
\echo === 4. アナライザで止まる（テーブル名の誤り）
SELECT id, title FROM book WHERE title = '実験用の本 42';
\echo === 5. アナライザで止まる（型が合わない）
SELECT id, title FROM books WHERE title = 42;
\echo === 6. ビューを作る
CREATE VIEW book_titles AS SELECT id, title FROM books;
\echo === 7. ビューの定義
\d+ book_titles
\echo === 8. ビューを検索すると、計画には books が出る
EXPLAIN SELECT id, title FROM book_titles WHERE title = '実験用の本 42';
\echo === 9. 元のテーブルの計画（比較）
EXPLAIN SELECT id, title FROM books WHERE title = '実験用の本 42';
\echo === 10. 実行まで進めると、計画と実行の時間が分かれて出る
EXPLAIN ANALYZE SELECT id, title FROM books WHERE title = '実験用の本 42';
\echo === 11. 片付け
DROP VIEW book_titles;

\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SHOW block_size;
CREATE EXTENSION IF NOT EXISTS pageinspect;
CREATE EXTENSION IF NOT EXISTS pg_visibility;

-- 各ページのレコード数を返す。ctid のページ番号ではなく、ページの中身（heap_page_items）を直接読む。
-- lp_flags = 1 は、レコードが入っている項目（LP_NORMAL）。
CREATE FUNCTION page_items(rel regclass)
RETURNS TABLE (page int, items int, new_versions int) AS $$
  SELECT g,
         (SELECT count(*)::int FROM heap_page_items(get_raw_page(rel::text, g)) WHERE lp_flags = 1),
         (SELECT count(*)::int FROM heap_page_items(get_raw_page(rel::text, g))
           WHERE lp_flags = 1 AND t_xmin::text::bigint = coalesce(nullif(current_setting('cats.update_xid', true), ''), '-1')::bigint AND t_xmax = 0)
  FROM generate_series(0, pg_relation_size(rel) / 8192 - 1) AS g
$$ LANGUAGE sql;

-- レコードが入っているページの数（ctid のページ番号を数える）
CREATE FUNCTION used_pages(rel regclass) RETURNS int AS $$
DECLARE n int;
BEGIN
  EXECUTE format('SELECT count(DISTINCT (ctid::text::point)[0])::int FROM %s', rel) INTO n;
  RETURN n;
END $$ LANGUAGE plpgsql;

\echo == 1. 第10章・第11章と同じ作り方の cats（CREATE TABLE ... AS）
CREATE TABLE cats WITH (autovacuum_enabled = false) AS
SELECT n AS id,
       CASE WHEN n <= 9000 THEN 'A' ELSE 'B' END AS blood_type
FROM generate_series(1, 10000) AS n;
CREATE INDEX cats_blood_type_idx ON cats(blood_type);
ANALYZE cats;

\echo -- 作成直後：ファイルのページ数と、レコードが入っているページ数
SELECT pg_relation_size('cats') / current_setting('block_size')::int AS file_pages,
       used_pages('cats') AS used_pages;

\echo -- 作成直後：ページ0と最後のページのレコード数
SELECT page, items FROM page_items('cats') WHERE page IN (0, 63) ORDER BY page;

\echo == 2. 8,000匹をB型へ更新したあと
-- UPDATE したトランザクションの番号を控える（新しいレコードの xmin と照らすため）。
-- UPDATE の直後に cats を全件読むと、読んだ時点で元のレコードが片付けられてしまうので、
-- このあとの確認は、ページの中身を直接読む関数（pageinspect）だけで行う。
BEGIN;
UPDATE cats SET blood_type = 'B' WHERE id <= 8000;
SELECT set_config('cats.update_xid', (txid_current() % 4294967296)::text, false) AS update_xid;
COMMIT;
SELECT pg_relation_size('cats') / current_setting('block_size')::int AS file_pages;

\echo -- ページを、中身の種類ごとにまとめる（連続するページを1行にする）
WITH layout AS (
  SELECT page, items,
         CASE WHEN items = 0 THEN '空のページ'
              WHEN new_versions > 0 THEN '新しいレコードが入ったページ'
              ELSE '元のレコードだけのページ' END AS kind
  FROM page_items('cats')
), islands AS (
  SELECT page, items, kind,
         page - row_number() OVER (PARTITION BY kind ORDER BY page) AS grp
  FROM layout
)
SELECT kind, min(page) AS from_page, max(page) AS to_page, count(*) AS pages, sum(items) AS items
FROM islands GROUP BY kind, grp ORDER BY from_page;

\echo == 3. VACUUM のあと
VACUUM (VERBOSE) cats;
SELECT pg_relation_size('cats') / current_setting('block_size')::int AS file_pages;

\echo -- 新しいレコード8,000件が入ったページ（VACUUM のあとも、残るレコードの ctid は変わらない）
SELECT min((ctid::text::point)[0]::int) AS first_page,
       max((ctid::text::point)[0]::int) AS last_page,
       count(DISTINCT (ctid::text::point)[0]) AS pages
FROM cats WHERE id <= 8000;

\echo -- 可視性マップ：all-visible の印が付いたページと、付かなかったページ
SELECT count(*) FILTER (WHERE all_visible) AS all_visible_pages,
       count(*) FILTER (WHERE NOT all_visible) AS not_all_visible_pages
FROM pg_visibility_map('cats');

\echo -- 印が付かなかったページの範囲と、その中のレコード数
WITH not_visible AS (
  SELECT blkno::int AS page FROM pg_visibility_map('cats') WHERE NOT all_visible
)
SELECT min(page) AS from_page, max(page) AS to_page, count(*) AS pages,
       sum((SELECT count(*) FROM heap_page_items(get_raw_page('cats', page)) WHERE lp_flags = 1)) AS items
FROM not_visible;

\echo == 4. 作り方とサイズによる、ファイルのページ数と使われたページ数の違い
-- CREATE TABLE ... AS と INSERT ... SELECT。COPY は psql の \copy で別に入れる。
DO $$
DECLARE n int;
BEGIN
  FOREACH n IN ARRAY ARRAY[1000, 10000, 100000, 1000000] LOOP
    EXECUTE format('CREATE TABLE ctas_%s WITH (autovacuum_enabled = false) AS SELECT g AS id, ''A''::text AS blood_type FROM generate_series(1, %s) g', n, n);
    EXECUTE format('CREATE TABLE ins_%s (id int, blood_type text) WITH (autovacuum_enabled = false)', n);
    EXECUTE format('INSERT INTO ins_%s SELECT g, ''A'' FROM generate_series(1, %s) g', n, n);
    EXECUTE format('CREATE TABLE copy_%s (id int, blood_type text) WITH (autovacuum_enabled = false)', n);
  END LOOP;
END $$;
\copy (SELECT g, 'A' FROM generate_series(1, 1000) g) TO '/tmp/cats-pages-copy.csv' CSV
\copy copy_1000 FROM '/tmp/cats-pages-copy.csv' CSV
\copy (SELECT g, 'A' FROM generate_series(1, 10000) g) TO '/tmp/cats-pages-copy.csv' CSV
\copy copy_10000 FROM '/tmp/cats-pages-copy.csv' CSV
\copy (SELECT g, 'A' FROM generate_series(1, 100000) g) TO '/tmp/cats-pages-copy.csv' CSV
\copy copy_100000 FROM '/tmp/cats-pages-copy.csv' CSV
\copy (SELECT g, 'A' FROM generate_series(1, 1000000) g) TO '/tmp/cats-pages-copy.csv' CSV
\copy copy_1000000 FROM '/tmp/cats-pages-copy.csv' CSV
\! rm -f /tmp/cats-pages-copy.csv

SELECT t.method, t.rows,
       pg_relation_size(t.name::regclass) / 8192 AS file_pages,
       used_pages(t.name::regclass) AS used_pages,
       pg_relation_size(t.name::regclass) / 8192 - used_pages(t.name::regclass) AS empty_pages
FROM (SELECT m.method, r.rows, m.prefix || '_' || r.rows AS name
      FROM (VALUES ('CREATE TABLE AS', 'ctas'), ('INSERT', 'ins'), ('COPY', 'copy')) AS m(method, prefix),
           (VALUES (1000), (10000), (100000), (1000000)) AS r(rows)) AS t
ORDER BY t.rows, t.method;

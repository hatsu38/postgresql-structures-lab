\set ON_ERROR_STOP on
\pset pager off
SELECT version();
SHOW block_size;
SHOW default_statistics_target;
SHOW autovacuum;

-- 第10章の補足「第9章のグループ数の見積もりがずれた理由」で使う読書記録200万件。
-- 作り方は ch10/stats/setup.sql と同じ（books は使わないので作らない）。
\echo == 1. 読書記録200万件を作る（ANALYZE はまだしない）
BEGIN;
CREATE TABLE reading_records (
  book_id bigint NOT NULL,
  finished_at timestamp NOT NULL
);
INSERT INTO reading_records
SELECT ((floor(power(1 + u * (power(1000001::float8, 0.2) - 1), 5))::bigint
          * 386413) % 1000000) + 1,
       timestamp '2026-08-24'
         + ((n::bigint * 104729) % 2419200) * interval '1 second'
FROM (SELECT n, n * 0.6180339887498949::float8
                - floor(n * 0.6180339887498949::float8) AS u
      FROM generate_series(1, 2000000) AS n) AS s;
COMMIT;

SELECT count(*) AS records,
       pg_relation_size('reading_records') / 8192 AS file_pages
FROM reading_records;

SELECT relpages, reltuples FROM pg_class WHERE relname = 'reading_records';

\echo == 2. 既定の統計目標（default_statistics_target=100）で ANALYZE VERBOSE を3回
ANALYZE VERBOSE reading_records;
SELECT n_distinct FROM pg_stats
WHERE tablename = 'reading_records' AND attname = 'book_id';

ANALYZE VERBOSE reading_records;
SELECT n_distinct FROM pg_stats
WHERE tablename = 'reading_records' AND attname = 'book_id';

ANALYZE VERBOSE reading_records;
SELECT n_distinct FROM pg_stats
WHERE tablename = 'reading_records' AND attname = 'book_id';

SELECT relpages, reltuples FROM pg_class WHERE relname = 'reading_records';

\echo == 3. 本の番号の種類数（実際）
SELECT count(DISTINCT book_id) AS actual_distinct FROM reading_records;

\echo == 4. 統計目標を1000にして ANALYZE VERBOSE
SET default_statistics_target = 1000;
ANALYZE VERBOSE reading_records;
SELECT n_distinct FROM pg_stats
WHERE tablename = 'reading_records' AND attname = 'book_id';
RESET default_statistics_target;

\echo == 5. 30,000ページより大きいテーブル（800万件、2列）では、読むページも30,000ページになるか
CREATE TABLE big_records AS
SELECT n::bigint AS id, timestamp '2026-08-24' + n * interval '1 second' AS finished_at
FROM generate_series(1, 8000000) AS n;
SELECT count(*) AS records,
       pg_relation_size('big_records') / 8192 AS file_pages
FROM big_records;
ANALYZE VERBOSE big_records;

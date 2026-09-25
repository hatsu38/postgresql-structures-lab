\set ON_ERROR_STOP on
BEGIN;
CREATE TABLE books (
  id bigint PRIMARY KEY,
  title text NOT NULL
);
CREATE TABLE reading_records (
  book_id bigint NOT NULL,
  finished_at timestamp NOT NULL
);
INSERT INTO books
SELECT n, '実験用の本 ' || n FROM generate_series(1, 1000000) AS n;
INSERT INTO reading_records
SELECT ((floor(power(1 + u * (power(1000001::float8, 0.2) - 1), 5))::bigint
          * 386413) % 1000000) + 1,
       timestamp '2026-08-24'
         + ((n::bigint * 104729) % 2419200) * interval '1 second'
FROM (SELECT n, n * 0.6180339887498949::float8
                - floor(n * 0.6180339887498949::float8) AS u
      FROM generate_series(1, 2000000) AS n) AS s;
ANALYZE books;
ANALYZE reading_records;
SELECT count(*) FROM books;
SELECT count(*) FROM reading_records;
COMMIT;

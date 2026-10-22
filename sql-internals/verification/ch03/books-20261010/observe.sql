\set ON_ERROR_STOP on
\pset pager off
BEGIN READ ONLY;
SELECT version();
SHOW block_size;
SELECT count(*) FROM books;
SELECT id, ctid, title FROM books ORDER BY id LIMIT 5;
SELECT pg_relation_size('books') AS bytes,
       pg_relation_size('books') / current_setting('block_size')::int AS pages;
SELECT (ctid::text::point)[0]::int AS page, count(*) AS records
FROM books GROUP BY page ORDER BY page LIMIT 8;
SELECT (ctid::text::point)[0]::int AS page, count(*) AS records,
       min(id) AS first_id, max(id) AS last_id
FROM books GROUP BY page ORDER BY page LIMIT 8;
SELECT (ctid::text::point)[0]::int AS page, count(*) AS records,
       min(id) AS first_id, max(id) AS last_id
FROM books GROUP BY page ORDER BY page DESC LIMIT 1;
COMMIT;

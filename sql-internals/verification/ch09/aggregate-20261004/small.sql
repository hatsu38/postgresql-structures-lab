\set ON_ERROR_STOP on
\pset pager off
\pset null '(NULL)'
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
SELECT book_id, count(*) AS read_count
FROM (VALUES (2), (1), (2), (4), (2)) AS records(book_id)
GROUP BY book_id
ORDER BY book_id;
SELECT count(*) AS records,
       count(minutes) AS measured_records,
       sum(minutes) AS total_minutes,
       avg(minutes) AS average_minutes
FROM (VALUES (10), (30), (50), (NULL::integer)) AS sessions(minutes);
SELECT count(*) AS records, count(minutes) AS measured_records,
       sum(minutes) AS total_minutes, avg(minutes) AS average_minutes
FROM (VALUES (NULL::integer)) AS sessions(minutes);
SELECT count(*) AS records, sum(minutes) AS total_minutes, avg(minutes) AS average_minutes
FROM (VALUES (10)) AS sessions(minutes) WHERE false;
\echo === group-count-experiment ===
CREATE TEMP TABLE few_groups (book_id integer NOT NULL);
CREATE TEMP TABLE many_groups (book_id integer NOT NULL);
INSERT INTO few_groups
SELECT (n - 1) % 10 + 1 FROM generate_series(1, 10000) AS n;
INSERT INTO many_groups
SELECT n FROM generate_series(1, 10000) AS n;
ANALYZE few_groups;
ANALYZE many_groups;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, count(*) FROM few_groups GROUP BY book_id;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, count(*) FROM many_groups GROUP BY book_id;
SELECT 'few_groups' AS source, count(*) AS groups, sum(n) AS total,
       min(n) AS smallest, max(n) AS largest
FROM (SELECT book_id, count(*) AS n FROM few_groups GROUP BY book_id) AS counts
UNION ALL
SELECT 'many_groups', count(*), sum(n), min(n), max(n)
FROM (SELECT book_id, count(*) AS n FROM many_groups GROUP BY book_id) AS counts;
DROP TABLE few_groups, many_groups;

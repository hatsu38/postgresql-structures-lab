\set ON_ERROR_STOP on
\pset pager off
CREATE TABLE cats WITH (autovacuum_enabled = false) AS
SELECT n AS id,
       CASE WHEN n <= 9000 THEN 'A' ELSE 'B' END AS blood_type
FROM generate_series(1, 10000) AS n;
CREATE INDEX cats_blood_type_idx ON cats(blood_type);
ANALYZE cats;
UPDATE cats SET blood_type = 'B' WHERE id <= 8000;
SELECT pg_sleep(1.5);
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'cats';
VACUUM cats;
SELECT pg_sleep(1.5);
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'cats';
DROP TABLE cats;

\set ON_ERROR_STOP on
\pset pager off
VACUUM (ANALYZE) books;
VACUUM (ANALYZE) reading_records;
SELECT relname, relpages, relallvisible FROM pg_class WHERE relname IN ('books','reading_records');

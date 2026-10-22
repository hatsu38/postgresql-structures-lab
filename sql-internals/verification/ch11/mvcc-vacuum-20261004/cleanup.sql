\set ON_ERROR_STOP on
DROP TABLE mvcc_reading_records;
DROP TABLE mvcc_books;
SELECT to_regclass('public.mvcc_books') IS NULL AS books_demo_removed,
       to_regclass('public.mvcc_reading_records') IS NULL AS records_demo_removed;
SELECT id, title FROM books WHERE id = 42;
SELECT book_id, finished_at FROM reading_records WHERE book_id = 42;
SELECT count(*) AS books FROM books;
SELECT count(*) AS records FROM reading_records;

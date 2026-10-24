\set ON_ERROR_STOP on
WITH demo_books(id, title) AS (
  VALUES (1, '星'), (2, '海'), (4, '森')
), demo_records(record_no, book_id) AS (
  VALUES (1, 2), (2, 1), (3, 2), (4, 4)
)
SELECT r.record_no, r.book_id, b.title
FROM demo_records AS r
JOIN demo_books AS b ON b.id = r.book_id
ORDER BY r.record_no;
WITH a(k) AS (VALUES (2), (2)), b(k) AS (VALUES (2), (2), (2))
SELECT count(*) AS combinations FROM a JOIN b ON a.k = b.k;

\set ON_ERROR_STOP on
CREATE INDEX books_title_idx ON books (title);
ANALYZE books;
CREATE TABLE books_observation (
  id bigint PRIMARY KEY,
  title text NOT NULL
);
INSERT INTO books_observation
SELECT id, title FROM books WHERE id BETWEEN 1 AND 1000 ORDER BY id;
ANALYZE books_observation;

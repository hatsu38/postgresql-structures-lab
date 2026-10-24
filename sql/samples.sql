-- 第8・9章の小さな例を、接続し直しても使える通常のテーブルに用意する。
-- 単独で実行するときは psql -1 -v ON_ERROR_STOP=1 -f samples.sql を使う。
\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS public.books_sample (
  id int PRIMARY KEY,
  title text
);
CREATE TABLE IF NOT EXISTS public.join_records_sample (
  book_id int
);
CREATE TABLE IF NOT EXISTS public.aggregate_records_sample (
  book_id int
);

TRUNCATE TABLE public.books_sample,
               public.join_records_sample,
               public.aggregate_records_sample;

INSERT INTO public.books_sample VALUES (1, '星'), (2, '海'), (4, '森');
INSERT INTO public.join_records_sample VALUES (2), (1), (2), (4);
INSERT INTO public.aggregate_records_sample VALUES (2), (1), (2), (4), (2);

ANALYZE public.books_sample;
ANALYZE public.join_records_sample;
ANALYZE public.aggregate_records_sample;

\echo 本3冊・JOIN用の記録4件・集計用の記録5件を用意しました。

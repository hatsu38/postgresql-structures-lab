-- 第10・11章の猫の実験を、A型9,000件・B型1,000件から始める。
-- 単独で実行するときは psql -1 -v ON_ERROR_STOP=1 -f cats.sql を使う。
\set ON_ERROR_STOP on

-- 更新による古いレコードや統計も取り除くため、catsだけを作り直す。
-- CREATE TABLE ASで作り、本文の測定と同じ保存方法にそろえる。
DROP TABLE IF EXISTS public.cats;
CREATE TABLE public.cats WITH (autovacuum_enabled = false) AS
SELECT n AS id,
       CASE WHEN n <= 9000 THEN 'A' ELSE 'B' END AS blood_type
FROM generate_series(1, 10000) AS n;

CREATE INDEX cats_blood_type_idx ON public.cats (blood_type);
ANALYZE public.cats;

\echo 猫1万匹（A型9,000件・B型1,000件）と血液型のIndex・統計を用意しました。

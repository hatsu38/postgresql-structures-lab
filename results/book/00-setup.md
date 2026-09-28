# 準備：実験環境を作る

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### SQLを入力する場所を作る

ターミナル:

```sh
git clone https://github.com/hatsu38/postgresql-structures-lab.git
cd postgresql-structures-lab
```

ターミナル:

```sh
docker compose up -d --wait
```

ターミナル:

```sh
docker compose exec db psql -X -U postgres -d reading_map
```

SQL:

```sql
\set ON_ERROR_STOP on
\pset pager off
```

実行結果:

```text
Pager usage is off.
```

SQL:

```sql
SELECT version();
```

実行結果:

```text
                                                         version
--------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) on aarch64-unknown-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
(1 row)
```

### 本100万冊と読了記録200万件を用意する

SQL:

```sql
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
```

実行結果:

```text
BEGIN
CREATE TABLE
CREATE TABLE
INSERT 0 1000000
INSERT 0 2000000
ANALYZE
ANALYZE
  count
---------
 1000000
(1 row)

  count
---------
 2000000
(1 row)
COMMIT
```

SQL:

```sql
ROLLBACK;
```

SQL:

```sql
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
```

実行結果:

```text
SET
SET
SET
```

実行結果:

```text
Gather  (cost=1000.00..13561.43 rows=1 width=30) (actual time=0.415..39.677 rows=1.00 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  Buffers: shared hit=1498 read=5855 dirtied=5882 written=5855
  ->  Parallel Seq Scan on books  (cost=0.00..12561.33 rows=1 width=30) (actual time=23.375..35.797 rows=0.33 loops=3)
        Filter: (title = '実験用の本 42'::text)
        Rows Removed by Filter: 333333
        Buffers: shared hit=1498 read=5855 dirtied=5882 written=5855
Planning:
  Buffers: shared hit=62 read=1 written=1
Planning Time: 0.486 ms
Execution Time: 39.765 ms
```

実行結果:

```text
JIT:
  Functions: 37
  Options: Inlining false, Optimization false, Expressions true, Deforming true
  Timing: Generation 1.441 ms (Deform 0.399 ms), Inlining 0.000 ms, Optimization 0.706 ms, Emission 12.385 ms, Total 14.533 ms
```

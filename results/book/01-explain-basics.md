# 第1章：EXPLAIN ANALYZEで、SQLの動きを観察する

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### まずは1冊を探そう

SQL:

```sql
SELECT id, title FROM books WHERE title = '実験用の本 42';
```

ターミナル:

```sh
docker compose exec db psql -X -U postgres -d reading_map
```

SQL:

```sql
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
\set ON_ERROR_STOP on
\pset pager off
```

### 1冊の題名検索で、何件を調べるか予想する

SQL:

```sql
SELECT id, title FROM books WHERE title = '実験用の本 42';
```

実行結果:

```text
 id |     title
----+---------------
 42 | 実験用の本 42
(1 row)
```

### EXPLAINは、実行する前の予定を見せる

SQL:

```sql
EXPLAIN
SELECT id, title FROM books WHERE title = '実験用の本 42';
```

実行結果:

```text
Seq Scan on books  (cost=0.00..19853.00 rows=1 width=30)
  Filter: (title = '実験用の本 42'::text)
```

### 予定だけでなく、実際のレコード数と時間を見る

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title = '実験用の本 42';
```

実行結果:

```text
Seq Scan on books  (cost=0.00..19853.00 rows=1 width=30) (actual time=0.036..35.994 rows=1.00 loops=1)
  Filter: (title = '実験用の本 42'::text)
  Rows Removed by Filter: 999999
  Buffers: shared hit=5112 read=2241
Planning Time: 0.008 ms
Execution Time: 36.037 ms
```

### 番号なら、別の探し方ができる

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE id = 42;
```

実行結果:

```text
Index Scan using books_pkey on books  (cost=0.42..8.44 rows=1 width=30) (actual time=0.017..0.017 rows=1.00 loops=1)
  Index Cond: (id = 42)
  Index Searches: 1
  Buffers: shared hit=7
Planning:
  Buffers: shared hit=5
Planning Time: 0.068 ms
Execution Time: 0.026 ms
```

### 自分で確かめる

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title = '存在しない本';
```

実行結果:

```text
Seq Scan on books  (cost=0.00..19853.00 rows=1 width=30) (actual time=40.821..40.821 rows=0.00 loops=1)
  Filter: (title = '存在しない本'::text)
  Rows Removed by Filter: 1000000
  Buffers: shared hit=5206 read=2147 written=78
Planning Time: 0.013 ms
Execution Time: 40.832 ms
```

### 実行結果を手元に残す

ターミナル:

```sh
docker compose exec -T db psql -X -U postgres -d reading_map \
  -a -f /lab/sql/01/01-observe.sql > results/local-chapter01.txt
```

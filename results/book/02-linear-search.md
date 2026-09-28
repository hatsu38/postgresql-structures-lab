# 第2章：LIMIT 1なら、見つかったところで止まるのか

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### 比較する条件をそろえる

SQL:

```sql
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
SET synchronize_seqscans = off;
```

実行結果:

```text
SET
SET
SET
SET
```

SQL:

```sql
SELECT count(*) FROM books;
```

実行結果:

```text
  count
---------
 1000000
(1 row)
```

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title = '実験用の本 42';
```

実行結果:

```text
Seq Scan on books  (cost=0.00..19853.00 rows=1 width=30) (actual time=0.009..36.378 rows=1.00 loops=1)
  Filter: (title = '実験用の本 42'::text)
  Rows Removed by Filter: 999999
  Buffers: shared hit=5537 read=1816 written=97
Planning:
  Buffers: shared hit=12
Planning Time: 0.083 ms
Execution Time: 36.396 ms
```

### 見つかったら止まってよいなら？

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books
WHERE title = '実験用の本 42'
LIMIT 1;
```

実行結果:

```text
Limit  (cost=0.00..19853.00 rows=1 width=30) (actual time=0.008..0.008 rows=1.00 loops=1)
  Buffers: shared hit=2
  ->  Seq Scan on books  (cost=0.00..19853.00 rows=1 width=30) (actual time=0.007..0.007 rows=1.00 loops=1)
        Filter: (title = '実験用の本 42'::text)
        Rows Removed by Filter: 41
        Buffers: shared hit=2
Planning Time: 0.055 ms
Execution Time: 0.019 ms
```

### 遅く見つかる本と、存在しない本も探す

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books
WHERE title = '実験用の本 999999'
LIMIT 1;
```

実行結果:

```text
Limit  (cost=0.00..19853.00 rows=1 width=30) (actual time=39.306..39.307 rows=1.00 loops=1)
  Buffers: shared hit=5746 read=1607 written=94
  ->  Seq Scan on books  (cost=0.00..19853.00 rows=1 width=30) (actual time=39.305..39.306 rows=1.00 loops=1)
        Filter: (title = '実験用の本 999999'::text)
        Rows Removed by Filter: 999998
        Buffers: shared hit=5746 read=1607 written=94
Planning Time: 0.038 ms
Execution Time: 39.319 ms
```

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books
WHERE title = '存在しない本'
LIMIT 1;
```

実行結果:

```text
Limit  (cost=0.00..19853.00 rows=1 width=30) (actual time=35.350..35.350 rows=0.00 loops=1)
  Buffers: shared hit=5841 read=1512 written=94
  ->  Seq Scan on books  (cost=0.00..19853.00 rows=1 width=30) (actual time=35.348..35.348 rows=0.00 loops=1)
        Filter: (title = '存在しない本'::text)
        Rows Removed by Filter: 1000000
        Buffers: shared hit=5841 read=1512 written=94
Planning Time: 0.067 ms
Execution Time: 35.368 ms
```

SQL:

```sql
RESET synchronize_seqscans;
```

実行結果:

```text
RESET
```

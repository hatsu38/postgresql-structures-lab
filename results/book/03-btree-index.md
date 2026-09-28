# 第3章：B-treeは、どうやって探す場所を絞るのか

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### 題名にもIndexを作る

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title = '実験用の本 42';
```

実行結果:

```text
Seq Scan on books  (cost=0.00..19853.00 rows=1 width=30) (actual time=0.010..38.387 rows=1.00 loops=1)
  Filter: (title = '実験用の本 42'::text)
  Rows Removed by Filter: 999999
  Buffers: shared hit=4657 read=2696 written=94
Planning Time: 0.051 ms
Execution Time: 38.405 ms
```

SQL:

```sql
CREATE INDEX books_title_idx ON books (title);
ANALYZE books;
```

実行結果:

```text
CREATE INDEX
ANALYZE
```

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title = '実験用の本 42';
```

実行結果:

```text
Index Scan using books_title_idx on books  (cost=0.42..8.44 rows=1 width=30) (actual time=0.053..0.054 rows=1.00 loops=1)
  Index Cond: (title = '実験用の本 42'::text)
  Index Searches: 1
  Buffers: shared hit=1 read=3
Planning:
  Buffers: shared hit=8 read=1
Planning Time: 0.150 ms
Execution Time: 0.067 ms
```

### 一点を探した後に、たくさん読む場合

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE id BETWEEN 400000 AND 400010;
```

実行結果:

```text
Index Scan using books_pkey on books  (cost=0.42..8.64 rows=11 width=30) (actual time=0.053..0.054 rows=11.00 loops=1)
  Index Cond: ((id >= 400000) AND (id <= 400010))
  Index Searches: 1
  Buffers: shared hit=3 read=4
Planning:
  Buffers: shared hit=6
Planning Time: 0.041 ms
Execution Time: 0.059 ms
```

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE id BETWEEN 1 AND 900000;
```

実行結果:

```text
Seq Scan on books  (cost=0.00..22353.00 rows=901290 width=30) (actual time=0.009..67.702 rows=900000.00 loops=1)
  Filter: ((id >= 1) AND (id <= 900000))
  Rows Removed by Filter: 100000
  Buffers: shared hit=5196 read=2157
Planning:
  Buffers: shared hit=2 read=2
Planning Time: 0.748 ms
Execution Time: 93.910 ms
```

### 目録の順番と、棚の順番が違うとき

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title >= '実験用の本 4' AND title < '実験用の本 5';
```

実行結果:

```text
Bitmap Heap Scan on books  (cost=3311.93..12314.92 rows=110000 width=30) (actual time=11.747..25.821 rows=111111.00 loops=1)
  Recheck Cond: ((title >= '実験用の本 4'::text) AND (title < '実験用の本 5'::text))
  Heap Blocks: exact=821
  Buffers: shared hit=1371
  ->  Bitmap Index Scan on books_title_idx  (cost=0.00..3284.43 rows=110000 width=0) (actual time=11.680..11.680 rows=111111.00 loops=1)
        Index Cond: ((title >= '実験用の本 4'::text) AND (title < '実験用の本 5'::text))
        Index Searches: 1
        Buffers: shared hit=550
Planning Time: 0.092 ms
Execution Time: 29.090 ms
```

#### 目録の順に取りに行くと、同じページに何度も戻る

SQL:

```sql
SELECT id, title FROM books
WHERE title >= '実験用の本 4' AND title < '実験用の本 5'
ORDER BY title LIMIT 8;
```

実行結果:

```text
   id   |       title
--------+-------------------
      4 | 実験用の本 4
     40 | 実験用の本 40
    400 | 実験用の本 400
   4000 | 実験用の本 4000
  40000 | 実験用の本 40000
 400000 | 実験用の本 400000
 400001 | 実験用の本 400001
 400002 | 実験用の本 400002
(8 rows)
```

#### 同じ11万冊を、ほかの方法で取り出すと

SQL:

```sql
SET enable_bitmapscan = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title >= '実験用の本 4' AND title < '実験用の本 5';
```

実行結果:

```text
Index Scan using books_title_idx on books  (cost=0.42..14532.64 rows=110000 width=30) (actual time=0.571..16.464 rows=111111.00 loops=1)
  Index Cond: ((title >= '実験用の本 4'::text) AND (title < '実験用の本 5'::text))
  Index Searches: 1
  Buffers: shared hit=22395
Planning Time: 0.131 ms
Execution Time: 19.673 ms
```

SQL:

```sql
SET enable_indexscan = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title >= '実験用の本 4' AND title < '実験用の本 5';
```

実行結果:

```text
Seq Scan on books  (cost=0.00..22353.00 rows=110000 width=30) (actual time=0.039..1785.254 rows=111111.00 loops=1)
  Filter: ((title >= '実験用の本 4'::text) AND (title < '実験用の本 5'::text))
  Rows Removed by Filter: 888889
  Buffers: shared hit=2583 read=4770
Planning Time: 0.083 ms
Execution Time: 1788.428 ms
```

SQL:

```sql
RESET enable_bitmapscan;
RESET enable_indexscan;
```

実行結果:

```text
RESET
RESET
```

### Indexにも保存容量と更新の負担がある

SQL:

```sql
SELECT pg_size_pretty(pg_relation_size('books_title_idx'));
```

実行結果:

```text
 pg_size_pretty
----------------
 39 MB
(1 row)
```

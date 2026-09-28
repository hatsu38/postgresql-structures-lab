# 第10章：PostgreSQLは、なぜその計画を選んだのか

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### 同じ「1種類」でも、件数は違う

SQL:

```sql
BEGIN;
CREATE TABLE stats_demo AS
SELECT n AS id,
       CASE WHEN n <= 9000 THEN 'popular' ELSE 'rare' END AS category
FROM generate_series(1, 10000) AS n;
CREATE INDEX stats_demo_category_idx ON stats_demo (category);
ANALYZE stats_demo;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stats_demo WHERE category = 'popular';
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stats_demo WHERE category = 'rare';
```

実行結果:

```text
Seq Scan on stats_demo  (cost=0.00..189.00 rows=9000 width=11) (actual time=0.006..0.682 rows=9000.00 loops=1)
  Filter: (category = 'popular'::text)
  Rows Removed by Filter: 1000
  Buffers: shared hit=64
Planning:
  Buffers: shared hit=8 read=1
Planning Time: 0.078 ms
Execution Time: 0.970 ms
```

実行結果:

```text
Index Scan using stats_demo_category_idx on stats_demo  (cost=0.29..35.78 rows=1000 width=11) (actual time=0.023..0.106 rows=1000.00 loops=1)
  Index Cond: (category = 'rare'::text)
  Index Searches: 1
  Buffers: shared hit=7 read=3
Planning Time: 0.017 ms
Execution Time: 0.141 ms
```

### 全レコードを毎回数えず、特徴を持っておく

SQL:

```sql
SELECT attname, n_distinct, most_common_vals, most_common_freqs,
       histogram_bounds
FROM pg_stats
WHERE schemaname = current_schema() AND tablename = 'stats_demo';
```

実行結果:

```text
 attname  | n_distinct | most_common_vals | most_common_freqs | histogram_bounds
----------+------------+------------------+-------------------+------------------
 category |          2 | {popular,rare}   | {0.9,0.1}         |
```

### 古いメモで計画を立てたら

SQL:

```sql
UPDATE stats_demo SET category = 'rare' WHERE id <= 8000;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stats_demo WHERE category = 'rare';
ANALYZE stats_demo;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stats_demo WHERE category = 'rare';
ROLLBACK;
```

実行結果:

```text
Index Scan using stats_demo_category_idx on stats_demo  (cost=0.29..51.55 rows=1672 width=11) (actual time=0.013..0.722 rows=9000.00 loops=1)
  Index Cond: (category = 'rare'::text)
  Index Searches: 1
  Buffers: shared hit=60
Planning Time: 0.077 ms
Execution Time: 0.996 ms
```

実行結果:

```text
Seq Scan on stats_demo  (cost=0.00..232.00 rows=9000 width=9) (actual time=0.143..0.799 rows=9000.00 loops=1)
  Filter: (category = 'rare'::text)
  Rows Removed by Filter: 1000
  Buffers: shared hit=107
Planning:
  Buffers: shared hit=11
Planning Time: 0.106 ms
Execution Time: 1.066 ms
```

### 第9章の736,097個は、なぜ7万個台と見積もられたのか

SQL:

```sql
SELECT count(DISTINCT book_id) AS actual_books FROM reading_records;
SELECT n_distinct FROM pg_stats
WHERE tablename = 'reading_records' AND attname = 'book_id';
```

実行結果:

```text
 actual_books
--------------
       736097
(1 row)

 n_distinct
------------
      75797
(1 row)
```

SQL:

```sql
BEGIN;
ALTER TABLE reading_records ALTER COLUMN book_id SET STATISTICS 10000;
ANALYZE reading_records;
SELECT n_distinct FROM pg_stats
WHERE tablename = 'reading_records' AND attname = 'book_id';
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, count(*) AS read_count
FROM reading_records GROUP BY book_id;
ROLLBACK;
```

実行結果:

```text
 n_distinct
------------
 -0.3680485
(1 row)

HashAggregate  (cost=143311.00..166296.97 rows=736097 width=16) (actual time=533.319..744.839 rows=736097.00 loops=1)
  Group Key: book_id
  Planned Partitions: 8  Batches: 9  Memory Usage: 8281kB  Disk Usage: 31440kB
  Buffers: shared hit=9252 read=1559, temp read=3239 written=6740
  ->  Seq Scan on reading_records  (cost=0.00..30811.00 rows=2000000 width=8) (actual time=0.131..130.200 rows=2000000.00 loops=1)
        Buffers: shared hit=9252 read=1559
Planning:
  Buffers: shared hit=29
Planning Time: 0.126 ms
Execution Time: 774.853 ms
```

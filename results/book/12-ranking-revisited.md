# 第12章：ランキングを速くする3つの案を、実行計画で比べる

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### 基準となるSQLを残す

SQL:

```sql
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
SELECT count(*) FROM books;
SELECT count(*) FROM reading_records;
```

SQL:

```sql
CREATE TEMP VIEW ranking_before AS
SELECT b.id, b.title, count(*) AS read_count
FROM books AS b
JOIN reading_records AS r ON r.book_id = b.id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21'
GROUP BY b.id, b.title
ORDER BY read_count DESC, b.id ASC
LIMIT 20;

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM ranking_before;
```

実行結果:

```text
Limit  (cost=129354.25..129354.30 rows=20 width=38) (actual time=576.650..576.657 rows=20.00 loops=1)
  Buffers: shared hit=6592 read=2680, temp read=9038 written=10753
  ->  Sort  (cost=129354.25..130574.82 rows=488229 width=38) (actual time=576.648..576.653 rows=20.00 loops=1)
        Sort Key: (count(*)) DESC, b.id
        Sort Method: top-N heapsort  Memory: 27kB
        Buffers: shared hit=6592 read=2680, temp read=9038 written=10753
        ->  HashAggregate  (cost=104805.36..116362.65 rows=488229 width=38) (actual time=498.999..555.530 rows=255238.00 loops=1)
              Group Key: b.id
              Planned Partitions: 8  Batches: 9  Memory Usage: 8281kB  Disk Usage: 15560kB
              Buffers: shared hit=6592 read=2680, temp read=9038 written=10753
              ->  Hash Join  (cost=36689.43..65899.61 rows=488229 width=30) (actual time=166.012..405.124 rows=499998.00 loops=1)
                    Hash Cond: (r.book_id = b.id)
                    Buffers: shared hit=6592 read=2680, temp read=7276 written=7276
                    ->  Index Only Scan using reading_records_order_idx on reading_records r  (cost=0.43..17277.01 rows=488229 width=8) (actual time=0.007..35.307 rows=499998.00 loops=1)
                          Index Cond: ((finished_at >= '2026-09-14 00:00:00'::timestamp without time zone) AND (finished_at < '2026-09-21 00:00:00'::timestamp without time zone))
                          Heap Fetches: 0
                          Index Searches: 1
                          Buffers: shared hit=1919
                    ->  Hash  (cost=17353.00..17353.00 rows=1000000 width=30) (actual time=165.769..165.771 rows=1000000.00 loops=1)
                          Buckets: 131072  Batches: 16  Memory Usage: 4883kB
                          Buffers: shared hit=4673 read=2680, temp written=5815
                          ->  Seq Scan on books b  (cost=0.00..17353.00 rows=1000000 width=30) (actual time=0.006..60.127 rows=1000000.00 loops=1)
                                Buffers: shared hit=4673 read=2680
Planning:
  Buffers: shared hit=21
Planning Time: 0.188 ms
Execution Time: 578.434 ms
```

### 案1：Indexで減る処理を確かめる

SQL:

```sql
BEGIN;
SET LOCAL enable_indexscan = off;
SET LOCAL enable_indexonlyscan = off;
SET LOCAL enable_bitmapscan = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM ranking_before;
ROLLBACK;
```

実行結果:

```text
Limit  (cost=152888.24..152888.29 rows=20 width=38) (actual time=634.337..634.343 rows=20.00 loops=1)
  Buffers: shared hit=13916 read=4248, temp read=9038 written=10749
  ->  Sort  (cost=152888.24..154108.82 rows=488229 width=38) (actual time=634.336..634.340 rows=20.00 loops=1)
        Sort Key: (count(*)) DESC, b.id
        Sort Method: top-N heapsort  Memory: 27kB
        Buffers: shared hit=13916 read=4248, temp read=9038 written=10749
        ->  HashAggregate  (cost=128339.35..139896.65 rows=488229 width=38) (actual time=558.750..613.946 rows=255238.00 loops=1)
              Group Key: b.id
              Planned Partitions: 8  Batches: 9  Memory Usage: 8281kB  Disk Usage: 15560kB
              Buffers: shared hit=13916 read=4248, temp read=9038 written=10749
              ->  Hash Join  (cost=36689.00..89433.60 rows=488229 width=30) (actual time=175.634..460.219 rows=499998.00 loops=1)
                    Hash Cond: (r.book_id = b.id)
                    Buffers: shared hit=13916 read=4248, temp read=7276 written=7276
                    ->  Seq Scan on reading_records r  (cost=0.00..40811.00 rows=488229 width=8) (actual time=0.113..76.162 rows=499998.00 loops=1)
                          Filter: ((finished_at >= '2026-09-14 00:00:00'::timestamp without time zone) AND (finished_at < '2026-09-21 00:00:00'::timestamp without time zone))
                          Rows Removed by Filter: 1500002
                          Buffers: shared hit=9149 read=1662
                    ->  Hash  (cost=17353.00..17353.00 rows=1000000 width=30) (actual time=175.281..175.282 rows=1000000.00 loops=1)
                          Buckets: 131072  Batches: 16  Memory Usage: 4883kB
                          Buffers: shared hit=4767 read=2586, temp written=5815
                          ->  Seq Scan on books b  (cost=0.00..17353.00 rows=1000000 width=30) (actual time=0.003..62.081 rows=1000000.00 loops=1)
                                Buffers: shared hit=4767 read=2586
Planning:
  Buffers: shared hit=12
Planning Time: 0.185 ms
Execution Time: 635.629 ms
```

### 案2：数えてから、題名を付ける

SQL:

```sql
CREATE TEMP VIEW ranking_after AS
SELECT b.id, b.title, top_books.read_count
FROM (
  SELECT book_id, count(*) AS read_count
  FROM reading_records
  WHERE finished_at >= timestamp '2026-09-14'
    AND finished_at < timestamp '2026-09-21'
  GROUP BY book_id
  ORDER BY read_count DESC, book_id ASC
  LIMIT 20
) AS top_books
JOIN books AS b ON b.id = top_books.book_id
ORDER BY top_books.read_count DESC, b.id ASC;

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM ranking_after;
```

実行結果:

```text
Nested Loop  (cost=22604.00..22772.68 rows=20 width=38) (actual time=164.705..165.474 rows=20.00 loops=1)
  Buffers: shared hit=1973 read=26, temp read=641 written=1378
  ->  Limit  (cost=22603.58..22603.63 rows=20 width=16) (actual time=164.674..164.680 rows=20.00 loops=1)
        Buffers: shared hit=1919, temp read=641 written=1378
        ->  Sort  (cost=22603.58..22800.62 rows=78816 width=16) (actual time=164.673..164.677 rows=20.00 loops=1)
              Sort Key: (count(*)) DESC, reading_records.book_id
              Sort Method: top-N heapsort  Memory: 26kB
              Buffers: shared hit=1919, temp read=641 written=1378
              ->  HashAggregate  (cost=19718.15..20506.31 rows=78816 width=16) (actual time=111.935..149.717 rows=255238.00 loops=1)
                    Group Key: reading_records.book_id
                    Batches: 5  Memory Usage: 8249kB  Disk Usage: 7224kB
                    Buffers: shared hit=1919, temp read=641 written=1378
                    ->  Index Only Scan using reading_records_order_idx on reading_records  (cost=0.43..17277.01 rows=488229 width=8) (actual time=0.007..32.766 rows=499998.00 loops=1)
                          Index Cond: ((finished_at >= '2026-09-14 00:00:00'::timestamp without time zone) AND (finished_at < '2026-09-21 00:00:00'::timestamp without time zone))
                          Heap Fetches: 0
                          Index Searches: 1
                          Buffers: shared hit=1919
  ->  Index Scan using books_pkey on books b  (cost=0.42..8.44 rows=1 width=30) (actual time=0.038..0.038 rows=1.00 loops=20)
        Index Cond: (id = reading_records.book_id)
        Index Searches: 20
        Buffers: shared hit=54 read=26
Planning:
  Buffers: shared hit=7
Planning Time: 0.148 ms
Execution Time: 166.251 ms
```

### 速くても、答えが変わったら困る

SQL:

```sql
SELECT count(*) AS records_without_book
FROM reading_records AS r
WHERE NOT EXISTS (SELECT 1 FROM books AS b WHERE b.id = r.book_id);
```

実行結果:

```text
 records_without_book
----------------------
                    0
(1 row)
```

SQL:

```sql
SELECT count(*) AS differing_rows FROM (
  (SELECT * FROM ranking_before EXCEPT ALL SELECT * FROM ranking_after)
  UNION ALL
  (SELECT * FROM ranking_after EXCEPT ALL SELECT * FROM ranking_before)
) AS differences;
```

実行結果:

```text
 differing_rows
----------------
              0
(1 row)
```

### 案3：表示する前に数えておく

SQL:

```sql
\timing on
```

実行結果:

```text
Timing is on.
```

SQL:

```sql
CREATE TABLE weekly_read_counts AS
SELECT book_id, count(*) AS read_count
FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
GROUP BY book_id;
CREATE INDEX weekly_read_counts_order_idx
ON weekly_read_counts (read_count DESC, book_id ASC);
ANALYZE weekly_read_counts;

EXPLAIN (ANALYZE, BUFFERS)
SELECT b.id, b.title, w.read_count
FROM weekly_read_counts AS w JOIN books AS b ON b.id = w.book_id
ORDER BY w.read_count DESC, w.book_id ASC LIMIT 20;
```

実行結果:

```text
SELECT 255238
Time: 195.385 ms
CREATE INDEX
Time: 93.357 ms
ANALYZE
Time: 18.157 ms
```

実行結果:

```text
Limit  (cost=0.84..13.87 rows=20 width=46) (actual time=0.038..0.137 rows=20.00 loops=1)
  Buffers: shared hit=100 read=3
  ->  Nested Loop  (cost=0.84..166283.20 rows=255238 width=46) (actual time=0.037..0.134 rows=20.00 loops=1)
        Buffers: shared hit=100 read=3
        ->  Index Only Scan using weekly_read_counts_order_idx on weekly_read_counts w  (cost=0.42..12948.39 rows=255238 width=16) (actual time=0.028..0.049 rows=20.00 loops=1)
              Heap Fetches: 20
              Index Searches: 1
              Buffers: shared hit=20 read=3
        ->  Index Scan using books_pkey on books b  (cost=0.42..0.60 rows=1 width=30) (actual time=0.004..0.004 rows=1.00 loops=20)
              Index Cond: (id = w.book_id)
              Index Searches: 20
              Buffers: shared hit=80
Planning:
  Buffers: shared hit=18 read=1
Planning Time: 0.217 ms
Execution Time: 0.151 ms
```

### 実験を終える

SQL:

```sql
DROP TABLE weekly_read_counts;
\timing off
```

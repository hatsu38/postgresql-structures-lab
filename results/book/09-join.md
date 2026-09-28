# 第9章：JOINと集計は、件数によって方法をどう変えるのか

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### 20件なら、一つずつ探す

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.book_id, b.title, r.finished_at
FROM (
  SELECT book_id, finished_at FROM reading_records
  ORDER BY finished_at DESC, book_id ASC LIMIT 20
) AS r
JOIN books AS b ON b.id = r.book_id
ORDER BY r.finished_at DESC, r.book_id ASC;
```

実行結果:

```text
Nested Loop  (cost=0.85..169.89 rows=20 width=38) (actual time=1.082..3.042 rows=20.00 loops=1)
  Buffers: shared hit=50 read=34 written=13
  ->  Limit  (cost=0.43..1.04 rows=20 width=16) (actual time=0.008..0.019 rows=20.00 loops=1)
        Buffers: shared hit=4
        ->  Index Only Scan using reading_records_order_idx on reading_records  (cost=0.43..60768.43 rows=2000000 width=16) (actual time=0.007..0.016 rows=20.00 loops=1)
              Heap Fetches: 0
              Index Searches: 1
              Buffers: shared hit=4
  ->  Index Scan using books_pkey on books b  (cost=0.42..8.44 rows=1 width=30) (actual time=0.150..0.150 rows=1.00 loops=20)
        Index Cond: (id = reading_records.book_id)
        Index Searches: 20
        Buffers: shared hit=46 read=34 written=13
Planning:
  Buffers: shared hit=18 read=2
Planning Time: 0.255 ms
Execution Time: 3.059 ms
```

### 何十万回も探すなら？

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.book_id, b.title
FROM reading_records AS r
JOIN books AS b ON b.id = r.book_id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21';
```

実行結果:

```text
Hash Join  (cost=36689.43..65899.61 rows=488229 width=30) (actual time=220.657..462.415 rows=499998.00 loops=1)
  Hash Cond: (r.book_id = b.id)
  Buffers: shared hit=6482 read=2790 written=94, temp read=7404 written=7404
  ->  Index Only Scan using reading_records_order_idx on reading_records r  (cost=0.43..17277.01 rows=488229 width=8) (actual time=0.009..35.626 rows=499998.00 loops=1)
        Index Cond: ((finished_at >= '2026-09-14 00:00:00'::timestamp without time zone) AND (finished_at < '2026-09-21 00:00:00'::timestamp without time zone))
        Heap Fetches: 0
        Index Searches: 1
        Buffers: shared hit=1919
  ->  Hash  (cost=17353.00..17353.00 rows=1000000 width=30) (actual time=220.387..220.388 rows=1000000.00 loops=1)
        Buckets: 131072  Batches: 16  Memory Usage: 4952kB
        Buffers: shared hit=4563 read=2790 written=94, temp written=5943
        ->  Seq Scan on books b  (cost=0.00..17353.00 rows=1000000 width=30) (actual time=0.008..84.017 rows=1000000.00 loops=1)
              Buffers: shared hit=4563 read=2790 written=94
Planning:
  Buffers: shared hit=15
Planning Time: 0.129 ms
Execution Time: 477.379 ms
```

### すでに並んでいるなら、合流できる

SQL:

```sql
BEGIN;
SET LOCAL enable_hashjoin = off;
SET LOCAL enable_nestloop = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT b.id, r.finished_at
FROM books AS b JOIN reading_records AS r ON r.book_id = b.id
WHERE b.id <= 100;
ROLLBACK;
```

実行結果:

```text
Merge Join  (cost=308490.01..318500.50 rows=214 width=16) (actual time=563.927..563.970 rows=141.00 loops=1)
  Merge Cond: (r.book_id = b.id)
  Buffers: shared hit=8871 read=1944, temp read=6854 written=12751
  ->  Sort  (cost=308488.69..313488.69 rows=2000000 width=16) (actual time=563.892..563.902 rows=142.00 loops=1)
        Sort Key: r.book_id
        Sort Method: external merge  Disk: 50896kB
        Buffers: shared hit=8867 read=1944, temp read=6854 written=12751
        ->  Seq Scan on reading_records r  (cost=0.00..30811.00 rows=2000000 width=16) (actual time=0.165..125.741 rows=2000000.00 loops=1)
              Buffers: shared hit=8867 read=1944
  ->  Index Only Scan using books_pkey on books b  (cost=0.42..10.30 rows=107 width=8) (actual time=0.028..0.040 rows=100.00 loops=1)
        Index Cond: (id <= 100)
        Heap Fetches: 100
        Index Searches: 1
        Buffers: shared hit=4
Planning:
  Buffers: shared hit=12
Planning Time: 0.165 ms
Execution Time: 568.076 ms
```

### 数えるときは、グループごとにメモする

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, count(*) AS read_count
FROM reading_records GROUP BY book_id;
```

実行結果:

```text
HashAggregate  (cost=40811.00..41599.81 rows=78881 width=16) (actual time=421.904..611.755 rows=736097.00 loops=1)
  Group Key: book_id
  Batches: 21  Memory Usage: 8257kB  Disk Usage: 27752kB
  Buffers: shared hit=8961 read=1850, temp read=4090 written=6731
  ->  Seq Scan on reading_records  (cost=0.00..30811.00 rows=2000000 width=8) (actual time=0.178..102.246 rows=2000000.00 loops=1)
        Buffers: shared hit=8961 read=1850
Planning Time: 0.070 ms
Execution Time: 634.511 ms
```

### ハッシュ表がメモリに収まらないとき

SQL:

```sql
SHOW work_mem;
SHOW hash_mem_multiplier;
```

実行結果:

```text
 work_mem
----------
 4MB
(1 row)

 hash_mem_multiplier
---------------------
 2
(1 row)
```

SQL:

```sql
BEGIN;
SET LOCAL work_mem = '64kB';
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.book_id, b.title
FROM reading_records AS r
JOIN books AS b ON b.id = r.book_id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21';
ROLLBACK;
```

実行結果:

```text
Hash Join  (cost=36689.43..65899.61 rows=488229 width=30) (actual time=216.690..418.515 rows=499998.00 loops=1)
  Hash Cond: (r.book_id = b.id)
  Buffers: shared hit=6404 read=2868, temp read=7824 written=7824
  ->  Index Only Scan using reading_records_order_idx on reading_records r  (cost=0.43..17277.01 rows=488229 width=8) (actual time=0.007..35.118 rows=499998.00 loops=1)
        Index Cond: ((finished_at >= '2026-09-14 00:00:00'::timestamp without time zone) AND (finished_at < '2026-09-21 00:00:00'::timestamp without time zone))
        Heap Fetches: 0
        Index Searches: 1
        Buffers: shared hit=1919
  ->  Hash  (cost=17353.00..17353.00 rows=1000000 width=30) (actual time=216.243..216.244 rows=1000000.00 loops=1)
        Buckets: 32768  Batches: 64  Memory Usage: 1249kB
        Buffers: shared hit=4485 read=2868, temp written=6218
        ->  Seq Scan on books b  (cost=0.00..17353.00 rows=1000000 width=30) (actual time=0.007..72.504 rows=1000000.00 loops=1)
              Buffers: shared hit=4485 read=2868
Planning:
  Buffers: shared hit=12
Planning Time: 0.160 ms
Execution Time: 432.850 ms
```

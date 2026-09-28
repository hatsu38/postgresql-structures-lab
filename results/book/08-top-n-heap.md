# 第8章：top-N heapsortは、上位20件をどう選ぶのか

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### 20件しか表示しないのに

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at
FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC
LIMIT 20;
```

### 候補が3枚なら、見るカードも減る？

実行結果:

```text
Limit  (cost=54092.78..54092.83 rows=20 width=16) (actual time=125.644..125.648 rows=20.00 loops=1)
  Buffers: shared hit=9545 read=1266
  ->  Sort  (cost=54092.78..55340.61 rows=499134 width=16) (actual time=125.639..125.641 rows=20.00 loops=1)
        Sort Key: finished_at DESC, book_id
        Sort Method: top-N heapsort  Memory: 26kB
        Buffers: shared hit=9545 read=1266
        ->  Seq Scan on reading_records  (cost=0.00..40811.00 rows=499134 width=16) (actual time=0.026..92.883 rows=499998.00 loops=1)
              Filter: ((finished_at >= '2026-09-14 00:00:00'::timestamp without time zone) AND (finished_at < '2026-09-21 00:00:00'::timestamp without time zone))
              Rows Removed by Filter: 1500002
              Buffers: shared hit=9545 read=1266
Planning Time: 0.111 ms
Execution Time: 125.690 ms
```

### 最初から順序が分かるなら？

SQL:

```sql
CREATE INDEX reading_records_order_idx
ON reading_records (finished_at DESC, book_id ASC);
ANALYZE reading_records;
```

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at
FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC
LIMIT 20;
```

実行結果:

```text
Limit  (cost=0.43..2.87 rows=20 width=16) (actual time=0.010..0.055 rows=20.00 loops=1)
  Buffers: shared hit=21 read=2
  ->  Index Only Scan using reading_records_order_idx on reading_records  (cost=0.43..60903.81 rows=498993 width=16) (actual time=0.009..0.052 rows=20.00 loops=1)
        Index Cond: ((finished_at >= '2026-09-14 00:00:00'::timestamp without time zone) AND (finished_at < '2026-09-21 00:00:00'::timestamp without time zone))
        Heap Fetches: 20
        Index Searches: 1
        Buffers: shared hit=21 read=2
Planning:
  Buffers: shared hit=11 read=4
Planning Time: 0.128 ms
Execution Time: 0.083 ms
```

### たくさん欲しくなったら、もう一度比べる

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at
FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC;
```

実行結果:

```text
Index Only Scan using reading_records_order_idx on reading_records  (cost=0.43..60903.81 rows=498993 width=16) (actual time=0.006..391.229 rows=499998.00 loops=1)
  Index Cond: ((finished_at >= '2026-09-14 00:00:00'::timestamp without time zone) AND (finished_at < '2026-09-21 00:00:00'::timestamp without time zone))
  Heap Fetches: 499998
  Index Searches: 1
  Buffers: shared hit=499275 read=2641 written=1750
Planning:
  Buffers: shared hit=4
Planning Time: 0.023 ms
Execution Time: 406.659 ms
```

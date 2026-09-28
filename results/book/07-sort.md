# 第7章：50万件のSortは、work_memに収まるのか

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### 新しい読了記録を上にしたい

SQL:

```sql
SELECT book_id, finished_at
FROM reading_records
ORDER BY finished_at DESC, book_id ASC;
```

### 用意してある200万件を使う

SQL:

```sql
SELECT count(*) FROM reading_records;
```

実行結果:

```text
  count
---------
 2000000
(1 row)
```

### Sortを観察する

SQL:

```sql
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '64MB';
```

実行結果:

```text
SET
SET
SET
```

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
Sort  (cost=88387.00..89643.06 rows=502425 width=16) (actual time=182.059..207.760 rows=499998.00 loops=1)
  Sort Key: finished_at DESC, book_id
  Sort Method: quicksort  Memory: 27913kB
  Buffers: shared hit=10811
  ->  Seq Scan on reading_records  (cost=0.00..40811.00 rows=502425 width=16) (actual time=0.022..80.506 rows=499998.00 loops=1)
        Filter: ((finished_at >= '2026-09-14 00:00:00'::timestamp without time zone) AND (finished_at < '2026-09-21 00:00:00'::timestamp without time zone))
        Rows Removed by Filter: 1500002
        Buffers: shared hit=10811
Planning Time: 0.083 ms
Execution Time: 223.929 ms
```

### 作業用メモリに収まらないとき

SQL:

```sql
SET work_mem = '64kB';
```

実行結果:

```text
SET
```

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
Sort  (cost=122183.71..123431.54 rows=499134 width=16) (actual time=289.741..325.654 rows=499998.00 loops=1)
  Sort Key: finished_at DESC, book_id
  Sort Method: external merge  Disk: 12784kB
  Buffers: shared hit=9451 read=1360, temp read=6367 written=6793
  ->  Seq Scan on reading_records  (cost=0.00..40811.00 rows=499134 width=16) (actual time=0.019..115.397 rows=499998.00 loops=1)
        Filter: ((finished_at >= '2026-09-14 00:00:00'::timestamp without time zone) AND (finished_at < '2026-09-21 00:00:00'::timestamp without time zone))
        Rows Removed by Filter: 1500002
        Buffers: shared hit=9451 read=1360
Planning Time: 0.269 ms
Execution Time: 341.417 ms
```

### メモリを増やせば、いつも解決？

SQL:

```sql
SET work_mem = '4MB';
```

実行結果:

```text
SET
```

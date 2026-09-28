# 第6章：長い実行計画は、どこから読むのか

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### ランキングの計画が読めない

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT b.id, b.title, count(*) AS read_count
FROM books AS b
JOIN reading_records AS r ON r.book_id = b.id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21'
GROUP BY b.id, b.title
ORDER BY read_count DESC, b.id ASC
LIMIT 20;
```

実行結果:

```text
Limit  (cost=153548.50..153548.55 rows=20 width=38) (actual time=627.239..627.244 rows=20.00 loops=1)
  Buffers: shared hit=4288 read=13879, temp read=9046 written=10758
  ->  Sort  (cost=153548.50..154780.84 rows=492937 width=38) (actual time=627.238..627.241 rows=20.00 loops=1)
        Sort Key: (count(*)) DESC, b.id
        Sort Method: top-N heapsort  Memory: 27kB
        Buffers: shared hit=4288 read=13879, temp read=9046 written=10758
        ->  HashAggregate  (cost=128762.88..140431.62 rows=492937 width=38) (actual time=552.463..606.428 rows=255238.00 loops=1)
              Group Key: b.id
              Planned Partitions: 8  Batches: 9  Memory Usage: 8281kB  Disk Usage: 15584kB
              Buffers: shared hit=4285 read=13879, temp read=9046 written=10758
              ->  Hash Join  (cost=36689.00..89481.96 rows=492937 width=30) (actual time=168.642..459.483 rows=499998.00 loops=1)
                    Hash Cond: (r.book_id = b.id)
                    Buffers: shared hit=4285 read=13879, temp read=7278 written=7278
                    ->  Seq Scan on reading_records r  (cost=0.00..40811.00 rows=492937 width=8) (actual time=0.154..101.089 rows=499998.00 loops=1)
                          Filter: ((finished_at >= '2026-09-14 00:00:00'::timestamp without time zone) AND (finished_at < '2026-09-21 00:00:00'::timestamp without time zone))
                          Rows Removed by Filter: 1500002
                          Buffers: shared hit=2048 read=8763
                    ->  Hash  (cost=17353.00..17353.00 rows=1000000 width=30) (actual time=168.081..168.082 rows=1000000.00 loops=1)
                          Buckets: 131072  Batches: 16  Memory Usage: 4883kB
                          Buffers: shared hit=2237 read=5116, temp written=5815
                          ->  Seq Scan on books b  (cost=0.00..17353.00 rows=1000000 width=30) (actual time=0.015..63.978 rows=1000000.00 loops=1)
                                Buffers: shared hit=2237 read=5116
Planning:
  Buffers: shared hit=103 read=6
Planning Time: 0.434 ms
Execution Time: 628.771 ms
```

### LimitとIndex Scanのレコードの受け渡し

SQL:

```sql
EXPLAIN
SELECT id, title FROM books ORDER BY title LIMIT 3;
```

実行結果:

```text
Limit  (cost=0.42..0.57 rows=3 width=30)
  ->  Index Scan using books_title_idx on books  (cost=0.42..49666.10 rows=1000000 width=30)
```

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books ORDER BY title LIMIT 3;
```

実行結果:

```text
Limit  (cost=0.42..0.57 rows=3 width=30) (actual time=0.015..0.016 rows=3.00 loops=1)
  Buffers: shared hit=2 read=2
  ->  Index Scan using books_title_idx on books  (cost=0.42..49247.50 rows=1000000 width=30) (actual time=0.014..0.015 rows=3.00 loops=1)
        Index Searches: 1
        Buffers: shared hit=2 read=2
Planning Time: 0.022 ms
Execution Time: 0.020 ms
```

#### 接続ごとに、別のバックエンドプロセスが動く

SQL:

```sql
SELECT pg_backend_pid();
```

実行結果:

```text
 pg_backend_pid
----------------
            952
(1 row)
```

ターミナル:

```sh
docker compose exec db psql -X -U postgres -d reading_map
```

SQL:

```sql
SELECT pg_backend_pid();
```

実行結果:

```text
 pg_backend_pid
----------------
          22521
(1 row)
```

SQL:

```sql
SELECT pid, state, query
FROM pg_stat_activity
WHERE datname = current_database();
```

実行結果:

```text
  pid  | state  |                query
-------+--------+-------------------------------------
 22521 | active | SELECT pid, state, query           +
       |        | FROM pg_stat_activity              +
       |        | WHERE datname = current_database();
   952 | idle   | SELECT pg_backend_pid();
(2 rows)
```

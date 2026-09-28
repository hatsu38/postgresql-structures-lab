# 付録：自分の遅いSQLを調べる

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

#### パターン1：条件の列を関数で包む

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM reading_records
WHERE date(finished_at) = date '2026-09-14';
```

実行結果:

```text
Aggregate  (cost=40836.00..40836.01 rows=1 width=8) (actual time=142.223..142.224 rows=1.00 loops=1)
  Buffers: shared read=10811
  ->  Seq Scan on reading_records  (cost=0.00..40811.00 rows=10000 width=0) (actual time=0.156..138.612 rows=71430.00 loops=1)
        Filter: (date(finished_at) = '2026-09-14'::date)
        Rows Removed by Filter: 1928570
        Buffers: shared read=10811
Planning:
  Buffers: shared hit=33 read=3
Planning Time: 0.441 ms
Execution Time: 142.243 ms
```

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-15';
```

実行結果:

```text
Aggregate  (cost=2790.24..2790.25 rows=1 width=8) (actual time=14.761..14.761 rows=1.00 loops=1)
  Buffers: shared read=278
  ->  Index Only Scan using reading_records_order_idx on reading_records  (cost=0.43..2606.93 rows=73325 width=0) (actual time=1.418..11.407 rows=71430.00 loops=1)
        Index Cond: ((finished_at >= '2026-09-14 00:00:00'::timestamp without time zone) AND (finished_at < '2026-09-15 00:00:00'::timestamp without time zone))
        Heap Fetches: 7
        Index Searches: 1
        Buffers: shared read=278
Planning:
  Buffers: shared hit=6 read=1
Planning Time: 0.127 ms
Execution Time: 14.784 ms
```

#### パターン2：前方一致のLIKEと照合順序

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title LIKE '実験用の本 4200%';
```

実行結果:

```text
Seq Scan on books  (cost=0.00..19853.00 rows=100 width=30) (actual time=1.151..73.120 rows=111.00 loops=1)
  Filter: (title ~~ '実験用の本 4200%'::text)
  Rows Removed by Filter: 999889
  Buffers: shared hit=1 read=7352
Planning:
  Buffers: shared hit=31 read=4
Planning Time: 0.749 ms
Execution Time: 73.143 ms
```

SQL:

```sql
BEGIN;
CREATE INDEX books_title_pattern_idx ON books (title text_pattern_ops);
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title LIKE '実験用の本 4200%';
ROLLBACK;
```

実行結果:

```text
Index Scan using books_title_pattern_idx on books  (cost=0.42..8.45 rows=100 width=30) (actual time=0.070..0.154 rows=111.00 loops=1)
  Index Cond: ((title ~>=~ '実験用の本 4200'::text) AND (title ~<~ '実験用の本 4201'::text))
  Filter: (title ~~ '実験用の本 4200%'::text)
  Index Searches: 1
  Buffers: shared hit=18 read=7
Planning:
  Buffers: shared hit=53 read=1
Planning Time: 0.303 ms
Execution Time: 0.172 ms
```

#### パターン3：複合Indexの列の順番

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records WHERE book_id = 42;
```

実行結果:

```text
Seq Scan on reading_records  (cost=0.00..35811.00 rows=24 width=16) (actual time=64.554..64.555 rows=1.00 loops=1)
  Filter: (book_id = 42)
  Rows Removed by Filter: 1999999
  Buffers: shared hit=95 read=10716
Planning:
  Buffers: shared hit=8
Planning Time: 0.091 ms
Execution Time: 64.573 ms
```

SQL:

```sql
BEGIN;
CREATE INDEX reading_records_book_first_idx ON reading_records (book_id, finished_at);
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records WHERE book_id = 42;
ROLLBACK;
```

実行結果:

```text
Index Only Scan using reading_records_book_first_idx on reading_records  (cost=0.43..8.85 rows=24 width=16) (actual time=0.061..0.062 rows=1.00 loops=1)
  Index Cond: (book_id = 42)
  Heap Fetches: 0
  Index Searches: 1
  Buffers: shared hit=4 read=3
Planning:
  Buffers: shared hit=7 read=1
Planning Time: 0.151 ms
Execution Time: 0.076 ms
```

SQL:

```sql
BEGIN;
CREATE INDEX reading_records_day_book_idx ON reading_records ((date(finished_at)), book_id);
ANALYZE reading_records;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM reading_records WHERE book_id = 42;
ROLLBACK;
```

実行結果:

```text
Aggregate  (cost=132.90..132.91 rows=1 width=8) (actual time=0.781..0.781 rows=1.00 loops=1)
  Buffers: shared hit=35 read=59
  ->  Index Only Scan using reading_records_day_book_idx on reading_records  (cost=0.43..132.84 rows=23 width=0) (actual time=0.174..0.777 rows=1.00 loops=1)
        Index Cond: (book_id = 42)
        Heap Fetches: 0
        Index Searches: 29
        Buffers: shared hit=35 read=59
Planning:
  Buffers: shared hit=19 read=1
Planning Time: 0.200 ms
Execution Time: 0.842 ms
```

#### パターン4：大きなOFFSET

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
ORDER BY finished_at DESC, book_id ASC
LIMIT 20 OFFSET 100000;
```

実行結果:

```text
Limit  (cost=3039.23..3039.84 rows=20 width=16) (actual time=18.797..18.802 rows=20.00 loops=1)
  Buffers: shared hit=3 read=385
  ->  Index Only Scan using reading_records_order_idx on reading_records  (cost=0.43..60776.43 rows=2000000 width=16) (actual time=0.867..15.084 rows=100020.00 loops=1)
        Heap Fetches: 9
        Index Searches: 1
        Buffers: shared hit=3 read=385
Planning:
  Buffers: shared hit=31
Planning Time: 0.121 ms
Execution Time: 18.820 ms
```

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
WHERE finished_at < '2026-09-19 14:24:00'
   OR (finished_at = '2026-09-19 14:24:00' AND book_id > 479127)
ORDER BY finished_at DESC, book_id ASC
LIMIT 20;
```

実行結果:

```text
Limit  (cost=0.43..1.23 rows=20 width=16) (actual time=4.998..5.002 rows=20.00 loops=1)
  Buffers: shared hit=387
  ->  Index Only Scan using reading_records_order_idx on reading_records  (cost=0.43..75768.43 rows=1899248 width=16) (actual time=4.997..4.999 rows=20.00 loops=1)
        Filter: ((finished_at < '2026-09-19 14:24:00'::timestamp without time zone) OR ((finished_at = '2026-09-19 14:24:00'::timestamp without time zone) AND (book_id > 479127)))
        Rows Removed by Filter: 100000
        Heap Fetches: 0
        Index Searches: 1
        Buffers: shared hit=387
Planning:
  Buffers: shared hit=6
Planning Time: 0.092 ms
Execution Time: 5.016 ms
```

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
WHERE finished_at <= '2026-09-19 14:24:00'
  AND (finished_at < '2026-09-19 14:24:00' OR book_id > 479127)
ORDER BY finished_at DESC, book_id ASC
LIMIT 20;
```

実行結果:

```text
Limit  (cost=0.43..1.20 rows=20 width=16) (actual time=0.021..0.025 rows=20.00 loops=1)
  Buffers: shared hit=4
  ->  Index Only Scan using reading_records_order_idx on reading_records  (cost=0.43..71953.53 rows=1853288 width=16) (actual time=0.020..0.022 rows=20.00 loops=1)
        Index Cond: (finished_at <= '2026-09-19 14:24:00'::timestamp without time zone)
        Filter: ((finished_at < '2026-09-19 14:24:00'::timestamp without time zone) OR (book_id > 479127))
        Rows Removed by Filter: 1
        Heap Fetches: 0
        Index Searches: 1
        Buffers: shared hit=4
Planning:
  Buffers: shared hit=20
Planning Time: 0.165 ms
Execution Time: 0.041 ms
```

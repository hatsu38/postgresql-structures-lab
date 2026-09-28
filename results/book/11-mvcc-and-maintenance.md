# 第11章：MVCCでは、更新中のレコードは読み手にどう見えるのか

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### 同じ読み手の見え方を固定する

SQL:

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT title FROM books WHERE id = 42;
```

SQL:

```sql
BEGIN;
UPDATE books SET title = '改訂版の本 42' WHERE id = 42;
COMMIT;
```

SQL:

```sql
SELECT title FROM books WHERE id = 42;
COMMIT;
SELECT title FROM books WHERE id = 42;
```

実行結果:

```text
実験用の本 42
```

実行結果:

```text
実験用の本 42
```

実行結果:

```text
改訂版の本 42
```

SQL:

```sql
UPDATE books SET title = '実験用の本 42' WHERE id = 42;
```

#### 版を、実物で見る

SQL:

```sql
BEGIN;
SELECT ctid, xmin, xmax, title FROM books WHERE id = 42;
UPDATE books SET title = '改訂版の本 42' WHERE id = 42;
SELECT ctid, xmin, xmax, title FROM books WHERE id = 42;
ROLLBACK;
SELECT ctid, xmin, xmax, title FROM books WHERE id = 42;
```

実行結果:

```text
    ctid    | xmin | xmax |     title
------------+------+------+---------------
 (7352,130) |  948 |    0 | 実験用の本 42
(1 row)

    ctid    | xmin | xmax |     title
------------+------+------+---------------
 (7352,131) |  999 |    0 | 改訂版の本 42
(1 row)

    ctid    | xmin | xmax |     title
------------+------+------+---------------
 (7352,130) |  948 |  999 | 実験用の本 42
(1 row)
```

SQL:

```sql
CREATE EXTENSION IF NOT EXISTS pageinspect;
BEGIN;
SELECT (ctid::text::point)[0]::int AS old_page FROM books WHERE id = 42 \gset
```

SQL:

```sql
UPDATE books SET title = '改訂版の本 42' WHERE id = 42;
SELECT (ctid::text::point)[0]::int AS new_page FROM books WHERE id = 42 \gset
```

SQL:

```sql
SELECT lp, t_xmin, t_xmax, t_ctid
FROM heap_page_items(get_raw_page('books', :old_page))
WHERE t_xmax = pg_current_xact_id()::xid
UNION ALL
SELECT lp, t_xmin, t_xmax, t_ctid
FROM heap_page_items(get_raw_page('books', :new_page))
WHERE t_xmin = pg_current_xact_id()::xid;
ROLLBACK;
```

実行結果:

```text
 lp  | t_xmin | t_xmax |   t_ctid
-----+--------+--------+------------
 130 |    948 |   1001 | (7352,132)
 132 |   1001 |      0 | (7352,132)
(2 rows)
```

### Indexだけで返せると思ったのに

SQL:

```sql
CREATE INDEX reading_records_visibility_idx
ON reading_records (book_id, finished_at);
VACUUM (ANALYZE) reading_records;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
WHERE book_id = 42
ORDER BY finished_at DESC, book_id ASC;
```

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS, WAL)
UPDATE reading_records SET finished_at = finished_at WHERE book_id = 42;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
WHERE book_id = 42
ORDER BY finished_at DESC, book_id ASC;
VACUUM (ANALYZE) reading_records;
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at FROM reading_records
WHERE book_id = 42
ORDER BY finished_at DESC, book_id ASC;
DROP INDEX reading_records_visibility_idx;
```

SQL:

```sql
SELECT pid, state, xact_start FROM pg_stat_activity
WHERE state = 'idle in transaction';
```

### 電源が切れたら、メモリの変更はどうなる？

実行結果:

```text
Update on reading_records  (cost=4.61..97.52 rows=0 width=0) (actual time=0.095..0.096 rows=0.00 loops=1)
  Buffers: shared hit=16 read=2 dirtied=2
  WAL: records=4 bytes=304
  ->  Bitmap Heap Scan on reading_records  (cost=4.61..97.52 rows=24 width=14) (actual time=0.009..0.010 rows=1.00 loops=1)
        Recheck Cond: (book_id = 42)
        Heap Blocks: exact=1
        Buffers: shared hit=4
        ->  Bitmap Index Scan on reading_records_visibility_idx  (cost=0.00..4.61 rows=24 width=0) (actual time=0.003..0.004 rows=1.00 loops=1)
              Index Cond: (book_id = 42)
              Index Searches: 1
              Buffers: shared hit=3
Planning:
  Buffers: shared hit=3
Planning Time: 0.037 ms
Execution Time: 0.340 ms
```

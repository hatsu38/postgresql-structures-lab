# 第5章：同じページを、毎回ストレージから読むのか

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### 前章の観察用テーブルを確認する

SQL:

```sql
SELECT count(*) FROM books_observation;
```

実行結果:

```text
 count
-------
  1000
(1 row)
```

SQL:

```sql
CREATE TABLE books_observation (
  id bigint PRIMARY KEY,
  title text NOT NULL
);
INSERT INTO books_observation
SELECT id, title FROM books WHERE id BETWEEN 1 AND 1000 ORDER BY id;
ANALYZE books_observation;
SELECT count(*) FROM books_observation;
```

実行結果:

```text
CREATE TABLE
INSERT 0 1000
ANALYZE
 count
-------
  1000
(1 row)
```

### 同じ検索を3回実行する

SQL:

```sql
CREATE EXTENSION IF NOT EXISTS pg_buffercache;
SELECT * FROM pg_buffercache_evict_relation('books_observation');
```

実行結果:

```text
CREATE EXTENSION
 buffers_evicted | buffers_flushed | buffers_skipped
-----------------+-----------------+-----------------
              11 |               8 |               0
(1 row)
```

SQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books_observation WHERE title = '実験用の本 42';
```

実行結果:

```text
Seq Scan on books_observation  (cost=0.00..20.50 rows=1 width=27) (actual time=0.124..0.324 rows=1.00 loops=1)
  Filter: (title = '実験用の本 42'::text)
  Rows Removed by Filter: 999
  Buffers: shared read=8
Planning:
  Buffers: shared hit=12
Planning Time: 0.033 ms
Execution Time: 0.329 ms
```

実行結果:

```text
Seq Scan on books_observation  (cost=0.00..20.50 rows=1 width=27) (actual time=0.005..0.038 rows=1.00 loops=1)
  Filter: (title = '実験用の本 42'::text)
  Rows Removed by Filter: 999
  Buffers: shared hit=8
Planning Time: 0.013 ms
Execution Time: 0.041 ms
```

実行結果:

```text
Seq Scan on books_observation  (cost=0.00..20.50 rows=1 width=27) (actual time=0.005..0.037 rows=1.00 loops=1)
  Filter: (title = '実験用の本 42'::text)
  Rows Removed by Filter: 999
  Buffers: shared hit=8
Planning Time: 0.012 ms
Execution Time: 0.040 ms
```

### メモリの領域を用途で分ける

SQL:

```sql
SHOW shared_buffers;
```

実行結果:

```text
 shared_buffers
----------------
 128MB
(1 row)
```

SQL:

```sql
SHOW work_mem;
```

実行結果:

```text
 work_mem
----------
 4MB
(1 row)
```

SQL:

```sql
SHOW temp_buffers;
```

実行結果:

```text
 temp_buffers
--------------
 8MB
(1 row)
```

SQL:

```sql
SHOW maintenance_work_mem;
```

実行結果:

```text
 maintenance_work_mem
----------------------
 64MB
(1 row)
```

### 観察用のテーブルを片付ける

SQL:

```sql
DROP TABLE books_observation;
```

実行結果:

```text
DROP TABLE
```

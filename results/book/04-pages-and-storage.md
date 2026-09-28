# 第4章：テーブルのレコードは、どのページに保存されているのか

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### 観察用の小さなテーブルを用意する

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

#### テーブルの保存先のパス

SQL:

```sql
SELECT pg_relation_filepath('books_observation');
```

実行結果:

```text
 pg_relation_filepath
----------------------
 base/17212/17223
(1 row)
```

#### テーブル本体と全体の大きさ

SQL:

```sql
SELECT pg_size_pretty(pg_relation_size('books_observation')) AS table_size,
       pg_size_pretty(pg_total_relation_size('books_observation')) AS total_size;
```

実行結果:

```text
 table_size | total_size
------------+------------
 64 kB      | 136 kB
(1 row)
```

#### 1ページの大きさ

SQL:

```sql
SHOW block_size;
```

実行結果:

```text
 block_size
------------
 8192
(1 row)
```

### レコードの場所を見てみる

SQL:

```sql
SELECT id, ctid, title
FROM books_observation ORDER BY id LIMIT 8;
```

実行結果:

```text
 id | ctid  |    title
----+-------+--------------
  1 | (0,1) | 実験用の本 1
  2 | (0,2) | 実験用の本 2
  3 | (0,3) | 実験用の本 3
  4 | (0,4) | 実験用の本 4
  5 | (0,5) | 実験用の本 5
  6 | (0,6) | 実験用の本 6
  7 | (0,7) | 実験用の本 7
  8 | (0,8) | 実験用の本 8
(8 rows)
```

### 7,353回は、何の数だったのか

SQL:

```sql
SELECT pg_size_pretty(pg_relation_size('public.books')) AS table_size,
       pg_relation_size('public.books') / current_setting('block_size')::int AS pages;
```

実行結果:

```text
 table_size | pages
------------+-------
 57 MB      |  7353
(1 row)
```

#### 木の段数と、hit・readの内訳を分ける

SQL:

```sql
CREATE EXTENSION IF NOT EXISTS pageinspect;
SELECT level FROM bt_metap('public.books_title_idx');
```

実行結果:

```text
 level
-------
     2
(1 row)
```

### 同じ1,000レコードなら、大きさも同じ？

SQL:

```sql
CREATE TABLE size_short AS
SELECT n AS id, repeat('a', 10) AS note
FROM generate_series(1, 1000) AS n;
CREATE TABLE size_long AS
SELECT n AS id, repeat('a', 200) AS note
FROM generate_series(1, 1000) AS n;
SELECT pg_relation_size('size_short') AS short_bytes,
       pg_relation_size('size_long') AS long_bytes;
```

実行結果:

```text
SELECT 1000
SELECT 1000
 short_bytes | long_bytes
-------------+------------
       65536 |     262144
(1 row)
```

### 比較用のテーブルを片付け、次章へ残すものを確認する

SQL:

```sql
DROP TABLE size_short, size_long;
```

実行結果:

```text
DROP TABLE
```

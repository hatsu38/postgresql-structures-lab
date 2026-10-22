# 『EXPLAINを読みながら学ぶPostgreSQLとアルゴリズム』のSQLを手元で実行する

本『EXPLAINを読みながら学ぶPostgreSQLとアルゴリズム ─ B-tree・ソート・ヒープ・ハッシュ表はどう動くか』のSQLを、手元で実行するための手順です。本には説明に使うSQLと実行結果を載せているので、手元で実行しなくても読み進められます。ここには、本に載せていない準備と後片付けのSQLをまとめています。

本の実行結果は、PostgreSQL 18.6で測定しました。処理時間やバッファアクセス数は、実行環境のスペックや直前の処理によって変わります。ミリ秒の一致ではなく、処理方法とレコード数を比べてください。本に載せた実行結果を測定したときのSQLと全出力は、[verification](verification/README.md)に置いています。

## 環境を作る

[リポジトリのREADME](../README.md)の「リポジトリを取得する」と「起動してデータを用意する」の手順で、本100万冊・読書記録200万件のデータを用意します。テーブルの作成とデータの投入は、この初期化手順に含まれているので、本の`CREATE TABLE`を手で実行する必要はありません。手元の環境で`books`の`title`列にIndexをすでに貼っている場合は、本と同じ実行計画にならないことがあります。

psqlでの接続方法は、READMEの「psqlで本のSQLを試す」を見てください。

## 共通設定

psqlでデータベースに接続したら、最初に次の設定を実行します。どれもセッション単位の設定なので、psqlを起動し直したときや接続し直したときは、そのたびに実行してください。

```sql
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
```

それぞれの設定の理由は次のとおりです。

- **`max_parallel_workers_per_gather = 0` / `jit = off`**
  複数プロセスでの並列処理と、実行時のコード生成（JITコンパイル）を止めます。並列化やJITが働くと実行計画が複雑になって、アルゴリズムの基本的な動きを追いにくくなるからです。本では、1つのプロセスが素直に処理する手順を観察します。
- **`work_mem = '4MB'`**
  ソートやハッシュテーブル作成などに使う作業用メモリの上限を、4MBに固定します。

## 第6章：ORDER BY

測定では、読書記録200万件を使い、`reading_records`にIndexが貼られていない状態で実行しています。第5章のSQLを続けて実行している場合は、そこで貼った日時のIndexを外してから試してください。

```sql
DROP INDEX IF EXISTS reading_records_finished_at_idx;
```

まず、`work_mem`を64MBにして、章の冒頭のSQLに`EXPLAIN (ANALYZE, BUFFERS)`を付けて実行します。

```sql
SET work_mem = '64MB';

EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at
FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC;
```

続いて64kBに変更し、同じEXPLAINのSQLをもう一度実行します。

```sql
SET work_mem = '64kB';
```

どちらもSeq Scanで期間に合うレコードを取り出し、Sortへ渡します。本に載せたのは、その後の並べ方の違いです。

実行後は、共通の設定へ戻しておきます。

```sql
SET work_mem = '4MB';
```

## 第7章：LIMITとヒープ

共通設定と、第6章を終えた状態を使います。`reading_records`にIndexが貼られていない状態で比べます。第5章の日時Indexをまだ外していなければ、次のSQLで外してください。

```sql
DROP INDEX IF EXISTS reading_records_finished_at_idx;
```

この章の最後の「第8章の準備」まで済ませている場合は、`reading_records_order_idx`も外してから比べます。

```sql
DROP INDEX IF EXISTS reading_records_order_idx;
```

作業用メモリを64MBにし、章の冒頭のSQLに`EXPLAIN (ANALYZE, BUFFERS)`を付けます。

```sql
SET work_mem = '64MB';

EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at
FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC
LIMIT 20;
```

`LIMIT 20`を外して実行すると、全件ソートと比較できます。実行結果の全体は[測定ログ](https://github.com/hatsu38/zenn/blob/main/_drafts/postgresql-sql-internals/verification/ch06-20261004/observe.log)で確認できます。

### 第8章の準備

作業用メモリを共通の設定に戻し、次章の実測で使うIndexを貼っておきます。このIndexの定義は次章の測定環境に合わせて、本番号のカラムも含めています。`ANALYZE`で統計情報も更新します。

```sql
SET work_mem = '4MB';
CREATE INDEX reading_records_order_idx
ON reading_records (finished_at DESC, book_id ASC);
ANALYZE reading_records;
```

## 第8章：JOIN

本3冊と読書記録4件を、一時テーブルに入れます。本物の`books`・`reading_records`と名前が重ならないように、`books_sample`・`records_sample`とします。`ANALYZE`で統計情報を更新しておきます。

```sql
CREATE TEMP TABLE books_sample (id int PRIMARY KEY, title text);
CREATE TEMP TABLE records_sample (book_id int);
INSERT INTO books_sample VALUES (1, '星'), (2, '海'), (4, '森');
INSERT INTO records_sample VALUES (2), (1), (2), (4);
ANALYZE books_sample;
ANALYZE records_sample;
```

結合のSQLは次のとおりです。

```sql
SELECT r.book_id, b.title
FROM records_sample AS r
JOIN books_sample AS b ON b.id = r.book_id;
```

```text
 book_id | title
---------+-------
       2 | 海
       1 | 星
       2 | 海
       4 | 森
(4 rows)
```

本の表8.2と同じ4件が返ります。本2の「海」も2回出ています。

このSQLに`EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)`を付けて、計画を見ます。`COSTS OFF`以降は、見積もりや時間の表示を省いて、件数と繰り返しの回数だけが見えるようにする指定です。

3つの方法を順に観察するために、`BEGIN`から`ROLLBACK`までの中で`SET LOCAL`を使います。`SET LOCAL`で変えた設定は、`ROLLBACK`で元に戻ります。

`Nested Loop`を観察するには、次のように実行します。

```sql
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_hashjoin = off;
SET LOCAL enable_mergejoin = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT r.book_id, b.title
FROM records_sample AS r
JOIN books_sample AS b ON b.id = r.book_id;
ROLLBACK;
```

`enable_hashjoin`と`enable_mergejoin`を`off`にして、ほかの2つが選ばれないようにしています。`enable_memoize`は、同じ番号で探した結果を再利用する仕組みの設定です。ここでは繰り返しそのものを見たいので、3つの方法を比べる間は、これも`off`にそろえます。ふだんの検索で無効にするための設定例ではありません。

内側にIndexを使う`Nested Loop`を観察するには、上の設定に`SET LOCAL enable_seqscan = off;`を加えます。外側の`Seq Scan`には`Disabled: true`と表示されますが、記録4件を読む方法がほかにないので、そのまま使われます。

`Hash Join`を観察するには、JOINの設定2行を次のように置き換えます。

```sql
SET LOCAL enable_nestloop = off;
SET LOCAL enable_mergejoin = off;
```

`Merge Join`を観察するには、次のように置き換えます。

```sql
SET LOCAL enable_nestloop = off;
SET LOCAL enable_hashjoin = off;
```

## 第9章：GROUP BY

読書記録5件を、一時テーブルに入れます。本物の`reading_records`と名前が重ならないように、第8章と同じ`records_sample`とします。第8章のSQLを同じ接続で試したあとなら、4件の`records_sample`が残っているので、先に削除してから作り直します。残っていなければ、削除するテーブルがないという通知が出るだけです。`ANALYZE`で統計情報を更新しておきます。

```sql
DROP TABLE IF EXISTS records_sample;
CREATE TEMP TABLE records_sample (book_id int);
INSERT INTO records_sample VALUES (2), (1), (2), (4), (2);
ANALYZE records_sample;
```

集計のSQLは次のとおりです。

```sql
SELECT book_id, count(*) AS read_count
FROM records_sample
GROUP BY book_id;
```

結果は本の表9.2と同じ3件です。`ORDER BY`を付けていないので、返ってくる順は決まっていません。

このSQLに`EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)`を付けて、計画を見ます。

```sql
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT book_id, count(*) AS read_count
FROM records_sample
GROUP BY book_id;
```

`GroupAggregate`を観察するには、`BEGIN`から`ROLLBACK`までの中で`SET LOCAL`を使います。

```sql
BEGIN;
SET LOCAL enable_hashagg = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT book_id, count(*) AS read_count
FROM records_sample
GROUP BY book_id;
ROLLBACK;
```

`enable_hashagg`を`off`にすると、`HashAggregate`が選ばれなくなります。もう一方の集計手順を観察するための設定で、ふだんの検索で無効にするための設定例ではありません。

確認が済んだら、一時テーブルを削除します。

```sql
DROP TABLE records_sample;
```

## 第10章：プランナと統計情報

### 猫の名簿を用意する

共通設定を使い、次のSQLを実行します。`generate_series`で1〜10,000の番号を作り、9,000までをA型、残りをB型にしています。

```sql
BEGIN;
CREATE TABLE cats AS
SELECT n AS id,
       CASE WHEN n <= 9000 THEN 'A' ELSE 'B' END AS blood_type
FROM generate_series(1, 10000) AS n;
CREATE INDEX cats_blood_type_idx ON cats(blood_type);
ANALYZE cats;
```

`BEGIN`から、最後の`ROLLBACK`までは、同じ接続で実行します。最後に変更を取り消すので、テーブルとIndexは残りません。途中で実験をやめる場合も`ROLLBACK`を実行してください。

作成してからコミットしていないテーブルを使うことで、別のプロセスによる統計の自動更新が入らないようにしています。通常は、設定された条件を満たすと自動で`ANALYZE`が行われます。

### 選ばれなかったScanのcostを確認する

`cats`を作った接続で、`UPDATE`の前に実行します。本の補足「選ばれなかったScanのcostを確認する」のSQLを実行したあと、この先の実験のため、設定を戻しておきます。

```sql
SET LOCAL enable_indexscan = on;
SET LOCAL enable_bitmapscan = on;
```

### 件数を確認して実験を終える

更新前・UPDATE後・ANALYZE後に、次のSQLで実際の件数を確認できます。統計の割合は本のSQLで見られ、`n_distinct`も同じSQLの列に足せば表示されます。

```sql
SELECT blood_type, count(*) FROM cats GROUP BY blood_type ORDER BY blood_type;
```

確認が済んだら、最初の`BEGIN`からの変更を取り消します。

```sql
ROLLBACK;
```

`cats`とそのIndexは消え、`SET LOCAL`で変えた設定も元に戻ります。

### 5件の集計のcost

この集計だけは、`cats`の実験とは別の接続で行ってください。第9章と同じ5件を用意します。

```sql
CREATE TEMP TABLE records_sample (book_id int);
INSERT INTO records_sample VALUES (2), (1), (2), (4), (2);
ANALYZE records_sample;
EXPLAIN
SELECT book_id, count(*) AS read_count
FROM records_sample GROUP BY book_id;
```

次にハッシュによる集計を無効にして、もう一方の計画を確認します。

```sql
BEGIN;
SET LOCAL enable_hashagg = off;
EXPLAIN
SELECT book_id, count(*) AS read_count
FROM records_sample GROUP BY book_id;
ROLLBACK;
DROP TABLE records_sample;
```

### 第9章のグループ数の見積もり

読書記録200万件の`reading_records`を使います。`ANALYZE`が調べる一部のレコードは毎回変わるので、手元の推定が本の77,812になるとは限りません。

```sql
SELECT n_distinct FROM pg_stats
WHERE schemaname = 'public' AND tablename = 'reading_records' AND attname = 'book_id';
EXPLAIN SELECT book_id, count(*) FROM reading_records GROUP BY book_id;
SELECT count(DISTINCT book_id) AS actual_groups FROM reading_records;
```

### 範囲検索の見積もり

本の補足「範囲検索ではどう見積もるか」は、本文の実験を終えたあとに別の接続で試します。「猫の名簿を用意する」のSQLを実行して、更新前の`cats`を作ってから、補足のSQLを実行してください。確認が済んだら、変更を取り消します。

```sql
ROLLBACK;
```

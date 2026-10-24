# 『EXPLAINを読みながら学ぶPostgreSQLとアルゴリズム』のSQLを手元で実行する

本『EXPLAINを読みながら学ぶPostgreSQLとアルゴリズム ─ B-tree・ソート・ヒープ・ハッシュ表はどう動くか』のSQLを、手元で実行するための手順です。各章の準備を済ませてから、本に載っているSQLを実行してください。初期化・接続・リセットは[ルートのREADME](../README.md)、本に載せていないテーブルの作成やIndexの付け外しは、この手順で確認できます。

本の実行結果は、PostgreSQL 18.6で測定しました。処理時間やバッファアクセス数は、実行環境のスペックや直前の処理によって変わります。実行計画の処理名とレコード数を比べてください。本に載せた実行結果を測定したときのSQLと全出力は、[verification](verification/README.md)に置いています。

## 環境を作る

[リポジトリのREADME](../README.md)の「リポジトリを取得する」と「起動してデータを用意する」の手順で、本100万冊・読書記録200万件のデータを用意します。テーブルの作成とデータの投入は、この初期化手順に含まれているので、本の`CREATE TABLE`を手で実行する必要はありません。手元の環境で`books`の`title`列にIndexをすでに貼っている場合は、本と同じ実行計画にならないことがあります。

psqlでの接続方法は、READMEの「psqlで本のSQLを試す」を見てください。

<a id="common-settings"></a>

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
  ソートなどの作業用メモリを4MBにします。ハッシュ処理では、この値に`hash_mem_multiplier`（既定で2）を掛けた量が基準になります。

各章の準備は、前の実験のトランザクションを終えてから実行します。`SET LOCAL`で方法を切り替える実験は、必ず`BEGIN`から`ROLLBACK`まで実行してください。エラーのあとにプロンプトが`reading_map=!#`になった場合も、まず`ROLLBACK;`を実行してからやり直します。

<a id="chapter-01"></a>

## 第1章：SQLの解析・計画・実行

初期データを使います。第4章以降から戻った場合は題名Indexを外し、同じ章をやり直す場合はビューも削除します。

```sql
DROP INDEX IF EXISTS books_title_idx;
DROP VIEW IF EXISTS book_titles;
ANALYZE books;
```

本の題名検索、`CREATE VIEW book_titles ...`、ビューを読む`EXPLAIN`の順に実行します。計画の`on books`から、ビューの元のテーブルを読むことを確認できます。`\d+ book_titles`はpsqlへの命令なので、ほかのSQLと分けて入力します。確認後はビューを削除できます。

```sql
DROP VIEW book_titles;
```

<a id="chapter-02"></a>

## 第2章：EXPLAIN

題名Indexがない状態で、本の`EXPLAIN`と`EXPLAIN (ANALYZE, BUFFERS)`を実行します。途中から始める場合は次を実行してください。

```sql
DROP INDEX IF EXISTS books_title_idx;
ANALYZE books;
```

`Seq Scan on books`、`actual`側の`rows=1`、`Rows Removed by Filter: 999999`を確認します。矢印でノードやFilterを説明した枠は、入力するSQLではありません。

<a id="chapter-03"></a>

## 第3章：ページとSeq Scan

初期データの`books`を使い、本の`ctid`・ページサイズ・ページ数のSQLを実行します。基本データを更新していなければ、追加の準備はありません。`ctid`の先頭の番号が同じレコードは、同じページに入っていることを確認します。

<a id="chapter-04"></a>

## 第4章：B-treeとIndex Scan

最初は題名Indexを外します。`books`の`id`にある主キーIndexは残します。

```sql
DROP INDEX IF EXISTS books_title_idx;
ANALYZE books;
```

本の順に、題名検索の`EXPLAIN`、`CREATE INDEX books_title_idx ...`と`ANALYZE`、同じ検索の`EXPLAIN`を実行します。`Seq Scan`から`Index Scan using books_title_idx`への変化を確かめます。題名Indexは第5章でも使うので残します。

<a id="chapter-05"></a>

## 第5章：共有バッファとBitmap Scan

途中から始める場合は、共有バッファの観察で使う題名Indexを用意します。

```sql
CREATE INDEX IF NOT EXISTS books_title_idx ON books (title);
ANALYZE books;
```

本の題名検索の`EXPLAIN (ANALYZE, BUFFERS)`を同じ接続で続けて2回実行し、`Buffers`の`hit`と`read`を比べます。すでにキャッシュにあると、1回目から`hit`になることもあります。

Bitmap Scanの観察では、読了日時のIndexを作る前に、以前の実験のIndexを外します。

```sql
DROP INDEX IF EXISTS reading_records_finished_at_idx;
DROP INDEX IF EXISTS reading_records_order_idx;
```

続いて、本の`CREATE INDEX reading_records_finished_at_idx ...`と`ANALYZE`、9月20日分を検索する`EXPLAIN`を実行します。`Bitmap Index Scan`・`Bitmap Heap Scan`と、実際に返す71,428件を確認します。このIndexは次章の準備で外します。

<a id="chapter-06"></a>

## 第6章：ORDER BY

測定では、読書記録200万件を使い、`reading_records`にIndexが貼られていない状態で実行しています。第5章のSQLを続けて実行している場合は、そこで貼った日時のIndexを外してから試してください。

```sql
DROP INDEX IF EXISTS reading_records_finished_at_idx;
DROP INDEX IF EXISTS reading_records_order_idx;
```

上のSQLでは、第8章以降で使う`reading_records_order_idx`も外します。まず、`work_mem`を64MBにして、章の冒頭のSQLに`EXPLAIN (ANALYZE, BUFFERS)`を付けて実行します。

```sql
SET work_mem = '64MB';

EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, finished_at
FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21'
ORDER BY finished_at DESC, book_id ASC;
```

続いて64kBに変更し、同じEXPLAINのSQLをもう一度実行します。64MBでは`Sort Method: quicksort`、64kBでは`Sort Method: external merge`と`Disk`を見比べます。

```sql
SET work_mem = '64kB';
```

どちらもSeq Scanで期間に合うレコードを取り出し、Sortへ渡します。本に載せたのは、その後の並べ方の違いです。

実行後は、共通の設定へ戻しておきます。

```sql
SET work_mem = '4MB';
```

<a id="chapter-07"></a>

## 第7章：LIMITとヒープ

共通設定と、第6章を終えた状態を使います。`reading_records`にIndexが貼られていない状態で比べます。第5章の日時Indexをまだ外していなければ、次のSQLで外してください。

```sql
DROP INDEX IF EXISTS reading_records_finished_at_idx;
```

第8章のIndexを作ってある場合は、`reading_records_order_idx`も外してから比べます。

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

`Sort Method: top-N heapsort`と、`Limit`が返す20件を確認します。`LIMIT 20`を外して実行すると、全件ソートと比較できます。実行結果の全体は[測定ログ](verification/reading-records/ch07.log)で確認できます。

<a id="chapter-08"></a>

## 第8章：JOIN

### 本3冊と読書記録4件で手順を追う

本3冊と読書記録4件は、初期化時に`public.books_sample`・`public.join_records_sample`へ入っています。以前から使っているDBへ追加する場合や、データを入れ直す場合は、[小さな例の初期化](../README.md#small-samples)を実行してください。

まず、結合のSQLを実行します。本文と同じ`public.join_records_sample`と`public.books_sample`を使います。

```sql
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;
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

本の表8.2と同じ4件が返ります。本2の「海」も2回出ています。`ORDER BY`を指定していないので、表示順は変わることがあります。

続いて、設定を切り替えずに選ばれる計画を見ます。

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;
```

サンプルの作成から、新しい接続でSELECTとEXPLAINを実行した手元の全出力は、[確認ログ](verification/small-samples/observe.log)にあります。[再現用SQL](verification/small-samples/observe.sql)でも同じ検索を試せます。

### 補足：結合方法を指定して比較する

小さな例を各方式で比較したSQLと全出力は、[compare.sql](verification/small-samples/compare.sql)と[compare.log](verification/small-samples/compare.log)にあります。

本文と同じように件数と繰り返し回数に表示を絞るには、`EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)`を使います。`COSTS OFF`以降は、見積もりや時間などの表示を省く指定です。

3つの方法を順に観察するために、`BEGIN`から`ROLLBACK`までの中で`SET LOCAL`を使います。`SET LOCAL`で変えた設定は、`ROLLBACK`で元に戻ります。

`Nested Loop`を観察するには、次のように実行します。

```sql
BEGIN;
SET LOCAL enable_memoize = off;
SET LOCAL enable_hashjoin = off;
SET LOCAL enable_mergejoin = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT r.book_id, b.title
FROM public.join_records_sample AS r
JOIN public.books_sample AS b ON b.id = r.book_id;
ROLLBACK;
```

`enable_hashjoin`と`enable_mergejoin`を`off`にして、ほかの2つが選ばれにくいようにしています。`enable_memoize`は、同じ番号で探した結果を再利用する仕組みの設定です。ここでは繰り返しそのものを見たいので、3つの方法を比べる間は、これも`off`にそろえます。ふだんの検索で無効にするための設定例ではありません。

内側にIndexを使う`Nested Loop`を観察するには、上の設定に`SET LOCAL enable_seqscan = off;`を加えます。外側の`Seq Scan`には`Disabled: true`と表示されますが、記録4件を読む方法がほかにないので、そのまま使われます。

`Hash Join`を観察するには、上の`enable_hashjoin`と`enable_mergejoin`の2行を次の2行に置き換えます。`enable_memoize = off`は残します。

```sql
SET LOCAL enable_nestloop = off;
SET LOCAL enable_mergejoin = off;
```

`Merge Join`を観察するには、次のように置き換えます。

```sql
SET LOCAL enable_nestloop = off;
SET LOCAL enable_hashjoin = off;
```

### 読書記録50万件で3つの結合を比べる

途中から始める場合も、次を実行してください。第5章の日時Indexを外し、読書記録50万件の結合で使うIndexを用意します。作業用メモリも4MBに戻します。

```sql
SET work_mem = '4MB';
DROP INDEX IF EXISTS reading_records_finished_at_idx;
CREATE INDEX IF NOT EXISTS reading_records_order_idx
ON reading_records (finished_at DESC, book_id ASC);
ANALYZE reading_records;
```

上の`BEGIN`〜`ROLLBACK`の枠で、EXPLAINとSELECTを次のSQLに置き換え、同じ3通りの設定で実行します。

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.book_id, b.title, r.finished_at
FROM reading_records AS r
JOIN books AS b ON b.id = r.book_id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21';
```

3つとも、結合が返す実際の件数は50万件です。Hash Joinでメモリを増やす比較は、その実験の`BEGIN`のあとに`SET LOCAL work_mem = '64MB';`を追加します。元のSQLと設定は[測定SQL](verification/reading-records/ch08.sql)にもあります。

小さな例のテーブルは、接続を閉じても残ります。第9章では別の集計用テーブルを使うので、この章のデータはそのままにして進めます。

<a id="chapter-09"></a>

## 第9章：GROUP BY

途中から始める場合も、共通設定で`work_mem`を4MBにしてから進めます。

読書記録5件は、初期化時に`public.aggregate_records_sample`へ入っています。第8章の4件とは別のテーブルなので、作り直す操作は不要です。

集計のSQLは次のとおりです。

```sql
SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample
GROUP BY book_id;
```

結果は本の表9.2と同じ3件です。`ORDER BY`を付けていないので、返ってくる順は決まっていません。

まず、設定を切り替えずに選ばれる計画を見ます。

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample
GROUP BY book_id;
```

この集計も、[再現用SQL](verification/small-samples/observe.sql)と[手元の確認ログ](verification/small-samples/observe.log)に含めています。

### 補足：集計方法を指定して比較する

2種類の集計と、第10章で比べるcostのSQL・全出力は、[compare.sql](verification/small-samples/compare.sql)と[compare.log](verification/small-samples/compare.log)にあります。

`GroupAggregate`を観察するには、`BEGIN`から`ROLLBACK`までの中で`SET LOCAL`を使います。

```sql
BEGIN;
SET LOCAL enable_hashagg = off;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)
SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample
GROUP BY book_id;
ROLLBACK;
```

`enable_hashagg`を`off`にすると、`HashAggregate`が選ばれなくなります。もう一方の集計手順を観察するための設定で、ふだんの検索で無効にするための設定例ではありません。

実データ200万件の比較では、本の`reading_records`を集計するSQLに`EXPLAIN (ANALYZE, BUFFERS)`を付け、通常の設定と`enable_hashagg = off`で実行します。後者は上と同じ`BEGIN`〜`ROLLBACK`の中で行います。どちらの集計方法でもグループ数が736,097件となり、各本の件数も一致することは[測定SQLとログ](verification/reading-records/README.md)で確認できます。

集計用テーブルも、次回そのまま使えます。データを変えた場合は、[小さな例の初期化](../README.md#small-samples)で入れ直せます。

<a id="chapter-10"></a>

## 第10章：プランナと統計情報

### 猫の初期データから始める

猫1万匹の`cats`は、初期化時に用意されています。`id`は1〜10,000の番号で、血液型はA型9,000件・B型1,000件です。すでに使っているDBへ追加する場合や、更新前の状態へ戻す場合は、先に[猫の初期化](../README.md#cats-sample)を実行してください。血液型のIndexと統計も準備済みなので、共通設定を使い、まずは検索のSQLを実行します。

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM cats WHERE blood_type = 'A';

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM cats WHERE blood_type = 'B';
```

初期状態では、A型にSeq Scan、B型にIndex Scanが選ばれます。この2つを観察するために、`SET LOCAL`で検索方法を切り替える操作は不要です。

続いて、本の順に統計とcostの確認、`UPDATE`、`ANALYZE`を実行します。更新後はA型1,000件・B型9,000件です。統計が古い状態を観察できるように、`cats`だけ自動バキュームを止めています。検索・更新・統計の全出力は、[猫の確認ログ](verification/cats-sample/README.md)にあります。

### 選ばれなかったScanのcostを確認する

`UPDATE`の前に、本の補足の`BEGIN`から`ROLLBACK`までを実行します。`ROLLBACK`で設定だけを戻し、準備済みの`cats`は残ります。

### 件数を確認する

更新前・UPDATE後・ANALYZE後に、次のSQLで実際の件数を確認できます。統計の割合は本のSQLで見られ、`n_distinct`も同じSQLの列に足せば表示されます。

```sql
SELECT blood_type, count(*) FROM cats GROUP BY blood_type ORDER BY blood_type;
```

確認が済んでも、通常テーブルの`cats`はそのまま残しておけます。やり直すときは、[猫の初期化](../README.md#cats-sample)でデータと統計を戻します。

### 5件の集計のcost

第9章で使った`public.aggregate_records_sample`を、そのまま使います。テーブルを作り直したり、別の接続を開いたりする準備は不要です。

```sql
EXPLAIN
SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample GROUP BY book_id;
```

次にハッシュによる集計を無効にして、もう一方の計画を確認します。

```sql
BEGIN;
SET LOCAL enable_hashagg = off;
EXPLAIN
SELECT book_id, count(*) AS read_count
FROM public.aggregate_records_sample GROUP BY book_id;
ROLLBACK;
```

### 第9章のグループ数の見積もり

読書記録200万件の`reading_records`を使います。`ANALYZE`が調べる一部のレコードは毎回変わるので、第9章の77,358や、統計を取り直したあとの76,011と、手元の推定が一致するとは限りません。

```sql
SELECT n_distinct FROM pg_stats
WHERE schemaname = 'public' AND tablename = 'reading_records' AND attname = 'book_id';
EXPLAIN SELECT book_id, count(*) FROM reading_records GROUP BY book_id;
SELECT count(DISTINCT book_id) AS actual_groups FROM reading_records;
```

### 範囲検索の見積もり

本の補足「範囲検索ではどう見積もるか」は、[猫の初期化](../README.md#cats-sample)で更新前の状態へ戻してから試します。本文で使う血液型の割合やページ数も初期状態へ戻るので、本文の途中で実行せず、本文の確認が済んでから行ってください。

<a id="chapter-11"></a>

## 第11章：MVCCとVACUUM

### 2つの接続を用意する

ターミナルを2つ開き、どちらもリポジトリのルートで次を実行します。本42をSELECTする側をプロセスA、題名をUPDATEする側をプロセスBとします。

```sh
docker compose exec db psql -X -U postgres -d reading_map
```

両方で共通設定を実行し、次の値が`read committed`であることを確認します。以前のトランザクションが残っていたら、先に`ROLLBACK;`で終えてください。

```sql
SHOW transaction_isolation;
```

### COMMIT前後で見える題名を比べる

まず、プロセスAで実験用テーブルを用意します。通常のテーブルなので、プロセスBからも使えます。このテーブルだけ自動バキュームを止めます。

```sql
CREATE TABLE mvcc_books (id bigint PRIMARY KEY, title text NOT NULL)
WITH (autovacuum_enabled = false);
INSERT INTO mvcc_books VALUES (42, '星の本');
SELECT id, title, ctid, xmin, xmax FROM mvcc_books WHERE id = 42;
```

次に、プロセスBで本の更新SQLを実行します。ここではまだCOMMITしません。

```sql
BEGIN;
UPDATE mvcc_books SET title = '新しい星の本' WHERE id = 42;
SELECT pg_current_xact_id();
SELECT id, title, ctid, xmin, xmax FROM mvcc_books WHERE id = 42;
```

続いて、プロセスAで次を実行します。プロセスAでは`BEGIN`を実行しません。

```sql
SELECT pg_current_snapshot();
SELECT id, title, ctid, xmin, xmax FROM mvcc_books WHERE id = 42;
VACUUM (VERBOSE) mvcc_books;
```

両方の結果を比べ、プロセスBには「新しい星の本」、プロセスAには「星の本」が表示されることを確認します。`xmin`・`xmax`とプロセスBのトランザクション番号も照らしてください。番号そのものは本の755・756とは変わります。VACUUMの`tuples:`行では`0 removed`を確認します。

その後、プロセスBで変更を確定します。

```sql
COMMIT;
```

最後に、プロセスAでもう一度確認します。

```sql
SELECT id, title, ctid, xmin, xmax FROM mvcc_books WHERE id = 42;
VACUUM (VERBOSE) mvcc_books;
```

プロセスAにも「新しい星の本」が返り、VACUUMで元のレコード1件を片付けたことを確認します。ほかに古いレコードが見えるトランザクションがあると、回収は待たされます。

本の冒頭の`ctid`の観察と、後の`xmin`・`xmax`の観察は、この1回の更新でまとめて確かめられます。プロセスBで同じ`BEGIN`・`UPDATE`を重ねて実行する必要はありません。

### 実行中のSELECTが元のレコードを残すことを確かめる

前の実験のCOMMITとVACUUMを終えてから、プロセスAで初期状態へ戻します。

```sql
TRUNCATE mvcc_books;
INSERT INTO mvcc_books VALUES (42, '星の本');
```

プロセスAで、30秒待つSELECTを開始します。

```sql
SELECT id, title, ctid, pg_sleep(30) FROM mvcc_books WHERE id = 42;
```

このSELECTが待っている間に、プロセスBで次を実行します。`BEGIN`は付けず、UPDATEをすぐに確定させます。

```sql
UPDATE mvcc_books SET title = '新しい星の本' WHERE id = 42;
VACUUM (VERBOSE) mvcc_books;
```

`0 removed`と`1 are dead but not yet removable`を確認します。プロセスAのSELECTが「星の本」を返して終わったら、プロセスBでもう一度VACUUMします。

```sql
VACUUM (VERBOSE) mvcc_books;
```

今度は元のレコードを片付けられることを確認します。操作が30秒に収まらなければ、`TRUNCATE`からやり直してください。確認が済んだら、プロセスAで削除します。

```sql
DROP TABLE mvcc_books;
```

### 猫の更新とVACUUM前後のページ数を見る

[猫の初期化](../README.md#cats-sample)で、A型9,000件・B型1,000件の状態へ戻します。ほかの接続でトランザクションが開いていない状態で、次を実行してください。

```sql
SELECT pg_relation_size('cats') / current_setting('block_size')::int AS pages;
UPDATE cats SET blood_type = 'B' WHERE id <= 8000;
SELECT pg_relation_size('cats') / current_setting('block_size')::int AS pages;
VACUUM (VERBOSE) cats;
SELECT pg_relation_size('cats') / current_setting('block_size')::int AS pages;
UPDATE cats SET blood_type = 'A' WHERE id <= 8000;
SELECT pg_relation_size('cats') / current_setting('block_size')::int AS pages;
```

ページ数の増加、VACUUM後にも残るページ、次の更新での領域の再利用を比べます。本の64→99→99→99は測定時の値です。テーブルの作り方や途中の操作で変わるため、[測定SQLと全出力](verification/ch11/cats-vacuum/README.md)も参照してください。

### Index Only ScanのHeap Fetchesを見る

本の表11.1では、読書記録を複製して使います。次のSQLで複製とIndexを用意し、VACUUM後の検索を確認します。`VACUUM`は`BEGIN`の外で実行します。

```sql
CREATE TABLE mvcc_reading_records WITH (autovacuum_enabled = false) AS
SELECT book_id, finished_at FROM reading_records;
CREATE INDEX mvcc_reading_records_book_time_idx
ON mvcc_reading_records (book_id, finished_at);
VACUUM (ANALYZE) mvcc_reading_records;
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT book_id, finished_at FROM mvcc_reading_records WHERE book_id = 42;
```

続いて日時を更新・確定し、同じ検索を実行します。

```sql
BEGIN;
UPDATE mvcc_reading_records
SET finished_at = finished_at + interval '1 second' WHERE book_id = 42;
COMMIT;
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT book_id, finished_at FROM mvcc_reading_records WHERE book_id = 42;
```

最後にVACUUMして、もう一度検索します。

```sql
VACUUM (VERBOSE) mvcc_reading_records;
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT book_id, finished_at FROM mvcc_reading_records WHERE book_id = 42;
DROP TABLE mvcc_reading_records;
```

3回の`Heap Fetches`を比べます。本の0→2→0は各段階で検索を1回ずつ実行した値です。更新直後の検索を繰り返すと、検索自体がIndexの項目に不要の印を付けるため、値が変わることがあります。ページの中身や可視性マップまで調べる測定SQLは[読書記録の実験](verification/reading-records/README.md)にあり、ルートのREADMEの`run.py`でまとめて実行できます。

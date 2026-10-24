# 『EXPLAINを読みながら学ぶPostgreSQLとアルゴリズム』の実験環境

[『EXPLAINを読みながら学ぶPostgreSQLとアルゴリズム ─ B-tree・ソート・ヒープ・ハッシュ表はどう動くか』](https://github.com/hatsu38/zenn/tree/main/books/postgresql-explain-algorithms)に出てくるSQLを実行し、自分で動作を確かめるためのリポジトリです。

初めて使うときは、下の手順でデータを用意して、題名検索を試してください。その後は、[章ごとの手順](sql-internals/README.md)で準備を済ませてから、本のSQLを実行します。途中の章から始める場合も、各章の手順を使えます。

## 必要なもの

Gitと、Docker DesktopなどのDocker Composeを使える環境を用意してください。PostgreSQLとpsqlはコンテナ内のものを使うので、手元へのインストールは不要です。測定に使ったPostgreSQL 18.6の公式イメージを、`compose.yaml`で固定しています。

本100万レコードと読書記録200万レコードを作ります。データ・Index・一時ファイル・Dockerイメージの保存に使うため、ディスクの空き容量を用意してください。

## リポジトリを取得する

```sh
git clone https://github.com/hatsu38/postgresql-structures-lab.git
cd postgresql-structures-lab
```

以降の`sh`枠は、このリポジトリのルートでターミナルに入力します。`sql`枠は、psqlでデータベースに接続してから入力します。

## 起動してデータを用意する

```sh
docker compose up -d --wait
docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -U postgres -d reading_map -f /lab/sql/01/00-setup.sql
docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -U postgres -d reading_map -f /lab/sql/01/02-check.sql
```

`00-setup.sql`は、空のDBで一度だけ実行します。本の「はじめに」にある`CREATE TABLE`も含まれるので、手でテーブルを作り直す必要はありません。再実行すると、同じ名前のテーブルがあるためエラーで止まります。途中で失敗した場合は、作成とデータの投入がまとめて取り消されます。

最後に「第1章の初期データを確認しました。」と表示されれば準備完了です。ファイル名の`sql/01/`は初期データを作るSQLの保存先で、以降の章も同じデータを使います。

| テーブル | 内容 | 初期状態 |
| --- | --- | --- |
| `books` | 番号と題名、100万レコード | `id`の主キーIndexあり、`title`のIndexなし |
| `reading_records` | 本の番号と読了日時、200万レコード | Indexなし |
| `books_sample` | 星・海・森の3冊 | `id`の主キーIndexあり |
| `join_records_sample` | 第8章のJOIN用の読書記録4件 | Indexなし |
| `aggregate_records_sample` | 第9章の集計用の読書記録5件 | Indexなし |

読書記録は2026年8月24日から9月20日までの4週間に分かれ、各週に50万件ずつあります。よく読まれる本に記録が偏るデータで、日時は200万件すべて異なります。乱数は使わないので、作り直しても同じデータになります。

<a id="small-samples"></a>

### 星・海・森の小さな例を用意する

星・海・森の小さな例も、初期化で用意されます。3つのサンプルテーブルは通常のテーブルなので、psqlで接続し直しても残ります。JOIN用と集計用を分けてあるため、章を移るときに記録を入れ直す必要はありません。

すでに初期化済みのDBへ小さな例を追加する場合や、小さな例だけをやり直す場合は、次を実行します。3つのサンプルテーブルを空にして、上の内容を入れ直します。`-1`で作成と投入を1つのトランザクションにまとめます。

```sh
docker compose exec -T db psql -X -1 -v ON_ERROR_STOP=1 -U postgres -d reading_map -f /lab/sql/samples.sql
```

## psqlで本のSQLを試す

```sh
docker compose exec db psql -X -U postgres -d reading_map
```

接続したら、次の2行をそれぞれ入力します。`\`で始まる行はpsqlへの命令なので、後ろのSQLとは分けて入力してください。

```sql
\set ON_ERROR_STOP on
```

```sql
\pset pager off
```

続いて、本と同じ共通設定にしてから、題名検索を試します。**接続し直したら、毎回この3つのSETを実行してください。**

```sql
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';

SELECT id, title FROM books WHERE title = '実験用の本 42';

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title FROM books WHERE title = '実験用の本 42';
```

検索では本42が1件返り、初期状態の実行計画には`Seq Scan on books`が出ます。`Gather`や`Parallel Seq Scan`が出る場合は、上の共通設定を同じ接続で実行したか確認してください。設定の意味は[共通設定](sql-internals/README.md#common-settings)にあります。

本の「実行結果」と付いた枠や、`…`で省略した出力は入力しません。第2章の矢印付きの計画も、表示の読み方を示す例です。psqlを終了するときは`\q`を入力します。

## 本の章に合わせて準備する

[章ごとの手順](sql-internals/README.md)に、Indexの付け外し、小さなテーブルの作成、設定の変更、後片付けをまとめています。章を順に試す場合も、次の章へ進む前に、その章の準備を確認してください。

| 本の章 | 手元で確かめること |
| --- | --- |
| [第1章：SQLの解析・計画・実行](sql-internals/README.md#chapter-01) | ビューから元のテーブルを読む計画 |
| [第2章：EXPLAIN](sql-internals/README.md#chapter-02) | 見積もりと実測、処理した件数 |
| [第3章：ページとSeq Scan](sql-internals/README.md#chapter-03) | `ctid`、ページの大きさと件数 |
| [第4章：B-treeとIndex Scan](sql-internals/README.md#chapter-04) | 題名Indexを作る前後の検索 |
| [第5章：共有バッファとBitmap Scan](sql-internals/README.md#chapter-05) | 同じ検索の`hit`・`read`、1日分の71,428件の検索 |
| [第6章：ORDER BY](sql-internals/README.md#chapter-06) | 50万件のソートを64MBと64kBで比較 |
| [第7章：LIMITとヒープ](sql-internals/README.md#chapter-07) | 全件ソートと上位20件の選択 |
| [第8章：JOIN](sql-internals/README.md#chapter-08) | 小さな例と50万件で3種類の結合を比較 |
| [第9章：GROUP BY](sql-internals/README.md#chapter-09) | ハッシュ表を使う集計と、並べてから行う集計 |
| [第10章：プランナと統計情報](sql-internals/README.md#chapter-10) | 猫1万匹の統計、cost、更新前後の見積もり |
| [第11章：MVCCとVACUUM](sql-internals/README.md#chapter-11) | 2つの接続から見える題名、元のレコードの片付け、Index Only Scan |

## 本の結果と見比べる

[検証ログの一覧](sql-internals/verification/README.md)から、章ごとのSQLと全出力を探せます。手元の結果では、実行計画の処理名、`actual`側の`rows`と`loops`、ソート方式などを比べてください。実行時間や`Buffers`の数は、環境や直前の処理によって変わります。`ANALYZE`が調べる標本も変わるため、推定件数は本と一致するとは限りません。

読書記録を使う第5〜11章の実験をまとめて動かし、ソート・上位20件・JOIN・集計の結果も照合したい場合は、DockerとPython 3で次を実行します。

```sh
python3 sql-internals/verification/reading-records/run.py /tmp/reading-records-results
```

出力先には、まだ存在しないディレクトリを指定します。専用コンテナを作って測定し、最後に削除するので、Composeで作ったDBは変わりません。成功すると`PASS:`と出力先が表示されます。条件と照合内容は[読書記録の実験](sql-internals/verification/reading-records/README.md)を参照してください。

## 中断・再開・やり直し

中断は`docker compose stop`、再開は`docker compose up -d --wait`です。データと作成済みのIndexは専用ボリュームに残ります。psqlで接続し直したら共通設定を入力し、[再開する章の準備](sql-internals/README.md)を確認します。一時テーブルと`SET`の設定は接続を閉じると失われ、未確定の変更も取り消されます。

### 初期データを入れた直後の状態に戻す

**この実験用DBのテーブル・Index・ビュー・拡張と、書き換えたデータをすべて削除して作り直します。** 同じDBへのほかの接続も切断します。

```sh
docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -U postgres -d reading_map -f /lab/sql/reset.sql
```

### ボリュームごと作り直す

DBが起動しないなど、上のリセットを使えない場合の手順です。**このCompose環境の実験データをすべて削除します。**

```sh
docker compose down --volumes
docker compose up -d --wait
docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -U postgres -d reading_map -f /lab/sql/01/00-setup.sql
docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -U postgres -d reading_map -f /lab/sql/01/02-check.sql
```

## SQLファイルが見つからない場合

`/lab/sql/01/00-setup.sql: No such file or directory`が出たら、手元とコンテナ内を比べます。

```sh
ls sql/01
docker compose exec -T db ls /lab/sql/01
```

手元にファイルがあるのにコンテナ内が空の場合は、コンテナを作り直してマウントし直します。この操作で接続は切れますが、DBの専用ボリュームは残ります。

```sh
docker compose up -d --force-recreate --wait db
docker compose exec -T db ls /lab/sql/01
```

初期化済みならセットアップを再実行せず、psqlで接続して各章の準備から進めてください。

## フォルダの案内

| 場所 | 内容 |
| --- | --- |
| [sql-internals/README.md](sql-internals/README.md) | この本の章ごとの準備・実行・後片付け |
| [sql-internals/verification/](sql-internals/verification/README.md) | この本の測定SQLと採取済みログ |
| `sql/01/`・`sql/samples.sql`・`sql/reset.sql` | 共通データと小さな例の初期化・初期状態の確認・リセット |
| `sql/00/`・`sql/02/`・`sql/12/`・[results/](results/README.md) | 旧構成の実験SQLとログ。現在の本の章番号とは対応しません |

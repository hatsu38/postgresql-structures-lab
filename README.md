# 『図解 SQLの裏側で動くアルゴリズムとPostgreSQLの仕組み』の実験環境

本『図解 SQLの裏側で動くアルゴリズムとPostgreSQLの仕組み ─ 実行計画で確かめて理解する』に対応する実験用リポジトリです。本の「準備」の章で案内する実験環境の作り方と、途中から実験を再開する手順は、このREADMEにまとめています。第1・2章と第12章の2,000万件の測り直しはSQLファイルを収録しています。ほかの章は本の本文のSQLで進めます。

Docker Desktopなど、Docker Composeを使える環境で実行してください。PostgreSQLやpsqlを手元に別途インストールする必要はありません。公式PostgreSQLイメージを使うので、Dockerfileのビルドも不要です。

## リポジトリを取得する

```sh
git clone https://github.com/hatsu38/postgresql-structures-lab.git
cd postgresql-structures-lab
```

## 起動してデータを用意する

このREADMEがあるディレクトリで実行します。

```sh
docker compose up -d --wait
docker compose exec -T db psql -X -U postgres -d reading_map -f /lab/sql/01/00-setup.sql
docker compose exec -T db psql -X -U postgres -d reading_map -a -f /lab/sql/01/01-observe.sql
docker compose exec -T db psql -X -U postgres -d reading_map -f /lab/sql/01/02-check.sql
```

初期データは本100万冊、読了記録200万件です。読了記録は、よく読まれる本ほど件数が多くなるように割り振ります（人気の順位 r の本の件数が r^-0.8 に比例する分布。乱数は使わないので、何度実行しても同じデータになります）。一番読まれた本は4週間で約2万件あり、1,000件以上の本は60冊です。一方で、記録が1〜2件の本が約62万冊、一度も読まれていない本も約26万冊あります。読了日時は2026年8月24日からの4週間に散らばります。番号には主キーのIndexがあり、題名にはIndexがありません。

`00-setup.sql`は空のDBで一度だけ実行します。再実行時は既存のテーブルを消さずエラーで停止します。中身は`BEGIN`から`COMMIT`までの一つのトランザクションなので、途中で失敗した場合は何も残りません。原因を直してから、もう一度実行してください。

初期データは以降の章でも使います。手元の環境では、booksテーブルと主キーのIndexで79 MB、読了記録で85 MBでした。作成中のログや、後の章で追加するIndexにも容量を使うので、空き容量は多めに用意してください。

## psqlで本のSQLを試す

```sh
docker compose exec db psql -X -U postgres -d reading_map
```

psqlに入り、本にある`sql`枠を入力します。実行結果の枠は入力しません。終了は `\q` です。

接続したら、エラーが起きたら止まる設定と、結果を一度に表示する設定をします。

```sql
\set ON_ERROR_STOP on
\pset pager off
```

`\`で始まる行は、SQLではなくpsqlへの命令です。複数行をまとめて貼り付けると、`\`で始まる行の後ろに続くSQLが、その命令の続きとして扱われて実行されないことがあります。`\`で始まる行と、その後ろのSQLは分けて貼り付けてください。

続けて、バージョンを確認します。本の実行結果はPostgreSQL 18.6で採りました。

```sql
SELECT version();
```

最後に、本の測定の共通設定をします。**接続し直したら、毎回この設定を入力します。**

```sql
SET max_parallel_workers_per_gather = 0;
SET jit = off;
SET work_mem = '4MB';
```

並列実行は複数のプロセスで処理を分担する仕組み、JITは実行時に処理の一部を機械語へ変換する仕組みです。本では一つのプロセスの仕事を1件ずつ追えるように、どちらも止めています。`work_mem`は並べ替えなどで使う作業用メモリの設定です。

<details>
<summary>設定し忘れたときに出る計画</summary>

既定の設定（`max_parallel_workers_per_gather = 2`、`jit = on`）のまま第1章の題名検索を実行すると、次のような計画が出ます（2026年9月26日、PostgreSQL 18.6）。

```text
Gather  (cost=1000.00..13561.43 rows=1 width=30) (actual time=0.415..39.677 rows=1.00 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  Buffers: shared hit=1498 read=5855 dirtied=5882 written=5855
  ->  Parallel Seq Scan on books  (cost=0.00..12561.33 rows=1 width=30) (actual time=23.375..35.797 rows=0.33 loops=3)
        Filter: (title = '実験用の本 42'::text)
        Rows Removed by Filter: 333333
        Buffers: shared hit=1498 read=5855 dirtied=5882 written=5855
Planning:
  Buffers: shared hit=62 read=1 written=1
Planning Time: 0.486 ms
Execution Time: 39.765 ms
```

`Workers Launched: 2`は、手伝いのプロセスが2つ動いたことを示します。`Parallel Seq Scan`は、SQLを受け取ったプロセスと手伝いの2つ、合わせて3つでテーブルを分けて読みました。`loops=3`はその3つを表し、`rows=0.33`や`Rows Removed by Filter: 333333`は、1つのプロセス当たりの平均です。`Gather`は、3つのプロセスが見つけたレコードを集める処理です。

序章のランキングのように見積もり（`cost`）の大きいSQLでは、出力の最後に`JIT:`の行も出ます。見積もりが既定で100000を超えると、処理の一部を機械語へ変換してから実行するためです。変換にかかった時間（`Timing`の`Total`）も`Execution Time`に含まれます。自分の結果に`Gather`や`JIT:`が出たら、共通設定をし忘れていないかを確かめてください。
</details>

## 本に載せた実行結果と見比べる

本の紙面では、本文が読む行だけを抜粋しています。本に載せていたSQLと実行結果の全文は、章ごとに [results/book/](results/book/README.md) にあります。時間と`Buffers`の数は、環境や直前の処理で変わります。ミリ秒の一致ではなく、処理方法とレコード数を比べてください。

## 第1章をまとめて実行する

```sh
docker compose exec -T db psql -X -U postgres -d reading_map -a -f /lab/sql/01/01-observe.sql > results/local-chapter01.txt
```

`results/local-chapter01.txt`を開くと、SQLと実行結果を確認できます。実行に失敗した場合は終了コードが0以外になります。バージョン・設定・件数・Indexの状態も先頭に記録します。

掲載用に採った実行結果は [results/chapter01-million-2026-09-23.txt](results/chapter01-million-2026-09-23.txt)、測定条件は [results/README.md](results/README.md) にあります。実行時間は環境やキャッシュ状態で変わります。ミリ秒の一致ではなく、処理方法と行数を比べてください。

## 第2章：LIMITで止まる場合と止まらない場合

第1章のデータをそのまま使い、題名のIndexを作る前に実行します。

```sh
docker compose exec -T db psql -X -U postgres -d reading_map -a -f /lab/sql/02/01-observe.sql > results/local-chapter02.txt
```

本42、本999999、存在しない本で比較します。観察SQLは接続ごとに並列実行とJITを無効にし、work_memを4MBにします。第2章だけsynchronize_seqscansを無効にして、終了時に戻します。

第1章で本100万冊・記録200万件を用意するので、第2章で本を追加したり、第7章で記録を作り直したりする必要はありません。旧版の1,000冊で準備済みの場合は、下記の「やり直し」を実験データを消してよいときにだけ行ってください。既存データを残す場合は別の空のDBでセットアップします。

## 第12章：2,000万件での測り直し

序章と同じ規模（本100万冊・読了記録2,000万件）で、第12章の3つの案を測ります。本の実験用DBとは別のDBを作り、終わったら消します。約2GBの領域を使います。

```sh
docker compose exec -T db psql -X -U postgres -c "CREATE DATABASE ranking_20m"
docker compose exec -T db psql -X -U postgres -d ranking_20m -a -f /lab/sql/12/ranking-20m.sql > results/local-ranking-20m.txt
docker compose exec -T db psql -X -U postgres -c "DROP DATABASE ranking_20m"
```

## 中断・再開・やり直し

中断は `docker compose stop`、再開は `docker compose up -d --wait`。データは専用ボリュームに残ります。

接続を閉じると、`SET`で指定した値と一時ビューは失われます。未完了のトランザクションも取り消されます。一方、COMMIT済みのテーブルやIndexは残るので、テーブルの作成SQLを再実行する必要はありません。再開したら、psqlで接続し直し、「psqlで本のSQLを試す」の設定をもう一度入力します。

### 章ごとに必要な状態

テーブルの件数は、どの章でも本100万冊・記録200万件のままです。

| 再開する章 | 開始時に必要な状態 | 章末に残るもの |
| --- | --- | --- |
| 第1〜2章 | 基本データあり、題名Indexなし | 基本データ |
| 第3章 | 題名Indexなし | `books_title_idx` |
| 第4章 | 題名Indexあり。`books_observation`を作る | `books_observation`を第5章へ残す |
| 第5章 | 題名Indexあり、`books_observation`に1,000冊 | `DROP TABLE`で観察用テーブルを削除 |
| 第6章 | 題名Indexあり。章末の補足では、接続A・Bを同じDBへつなぐ | テーブル・Indexの変更なし |
| 第7章 | 日時Indexなし | `work_mem`を4MBへ戻す |
| 第8章 | 日時Indexなし | `reading_records_order_idx` |
| 第9章 | 日時Indexあり | 実験用の設定はROLLBACKで戻す |
| 第10章 | 基本データあり。実験用テーブルは冒頭から同じ接続で作る | ROLLBACKで`stats_demo`は消える |
| 第11章 | 日時Indexあり、A・Bの以前のトランザクションは終了 | 題名を復元し、可視性実験用Indexを削除する |
| 第12章 | 日時Indexあり。一時ビューはその接続で作る | 章末で集計テーブルとそのIndexを削除。一時ビューは切断で消える |

### 途中の章から始める

作業中のトランザクションを終えてから、psqlで実行します。

第1〜3章へ戻り、題名Indexなしからやり直すときは、第3章で作ったIndexだけを削除します。

```sql
DROP INDEX IF EXISTS public.books_title_idx;
ANALYZE public.books;
```

第4〜6章から始めるときは、第3章と同じ定義の題名Indexを用意します。第4章から作り直す場合は、本で作った観察用テーブルも削除します。第5章から再開する場合は削除せず、同章の件数確認から進めます。

```sql
CREATE INDEX IF NOT EXISTS books_title_idx ON public.books (title);
ANALYZE public.books;
DROP TABLE IF EXISTS books_observation, size_short, size_long;
```

第7〜8章へ戻り、日時Indexなしからやり直すときは、第8章と第11章で作ったIndexを削除します。

```sql
DROP INDEX IF EXISTS public.reading_records_order_idx;
DROP INDEX IF EXISTS public.reading_records_visibility_idx;
ANALYZE public.reading_records;
```

第9章以降から始めるときは、第8章と同じ定義の日時Indexを用意します。第11章を途中からやり直す場合は、A・Bのトランザクションを終了し、可視性実験用Indexも削除します。

```sql
CREATE INDEX IF NOT EXISTS reading_records_order_idx
ON public.reading_records (finished_at DESC, book_id ASC);
ANALYZE public.reading_records;
DROP INDEX IF EXISTS public.reading_records_visibility_idx;
```

第12章をやり直すときは、新しい接続で一時ビューを作り直し、事前集計テーブルを削除してから始めます。

```sql
DROP TABLE IF EXISTS public.weekly_read_counts;
```

これまでの観察でキャッシュ、統計、可視性マップなどの状態は変わっています。これらの準備で、初回と同じ時間まで再現されるわけではありません。比べる実験どうしで条件をそろえ、方法・レコード数・アクセス量を確かめてください。

### 初期データを入れた直後の状態に戻す

第1章の最初からやり直すときは、DBを起動したまま次を実行します。**このDBで作ったテーブル・Index・拡張と、書き換えたデータをすべて削除します。**

```sh
docker compose exec -T db psql -X -U postgres -d reading_map -f /lab/sql/reset.sql
```

`00-setup.sql`を実行した直後と同じ状態に戻り、最後に`02-check.sql`で件数を確認します。同じDBへの他の接続は切断されるので、psqlを開いたままなら接続し直してください。手元では10秒ほどで終わります。

### ボリュームごと作り直す

DBが起動しないなど、上のリセットが使えない場合だけ、次を実行します。**このCompose環境の実験データを削除します。**

```sh
docker compose down --volumes
docker compose up -d --wait
docker compose exec -T db psql -X -U postgres -d reading_map -f /lab/sql/01/00-setup.sql
```

ホストへのポート公開はしていません。接続には `docker compose exec` を使います。パスワードはローカル実験専用の固定値です。

## SQLファイルが見つからない場合

`/lab/sql/01/00-setup.sql: No such file or directory` が出たら、まず手元とコンテナ内を比べます。

```sh
ls sql/01
docker compose exec -T db ls /lab/sql/01
```

手元にファイルがあるのにコンテナ内が空の場合、起動中のコンテナのバインドマウントが現在のディレクトリを参照できていない可能性があります。Gitの切り替えなどでマウント元のディレクトリが作り直された場合にも起こりえます。コンテナを再作成して、マウントをやり直してください。

```sh
docker compose up -d --force-recreate --wait db
docker compose exec -T db ls /lab/sql/01
```

この操作は接続を一度切りますが、DBの専用ボリュームは削除しません。`down --volumes`は不要です。

初期化済みなら、セットアップを再実行せず、データを確認してから観察用SQLへ進みます。

```sh
docker compose exec -T db psql -X -U postgres -d reading_map -f /lab/sql/01/02-check.sql
docker compose exec -T db psql -X -U postgres -d reading_map -a -f /lab/sql/01/01-observe.sql
```

まだテーブルを作っていない場合だけ、`00-setup.sql`を実行してください。

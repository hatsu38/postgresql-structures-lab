# いつものSQLで学ぶデータ構造とアルゴリズム — 実験環境

Zennの本 `postgresql-query-journey` に対応する実験用リポジトリです。現在は第1・2章の環境・SQL・実行結果を収録しています。第3〜12章は本の本文のSQLで進めます。

Docker Desktopなど、Docker Composeを使える環境で実行してください。PostgreSQLやpsqlを手元に別途インストールする必要はありません。公式PostgreSQLイメージを使うので、Dockerfileのビルドも不要です。

## リポジトリを取得する

```sh
git clone https://github.com/hatsu38/postgresql-structures-lab.git
cd postgresql-structures-lab
```

現在は非公開リポジトリです。取得にはリポジトリへのアクセス権が必要です。

## 起動してデータを用意する

このREADMEがあるディレクトリで実行します。

```sh
docker compose up -d --wait
docker compose exec -T db psql -X -U postgres -d reading_map -f /lab/sql/01/00-setup.sql
docker compose exec -T db psql -X -U postgres -d reading_map -a -f /lab/sql/01/01-observe.sql
docker compose exec -T db psql -X -U postgres -d reading_map -f /lab/sql/01/02-check.sql
```

初期データは本100万冊、読了記録200万件です。読了記録は、よく読まれる本ほど件数が多くなるように割り振ります（人気の順位 r の本の件数が r^-0.8 に比例する分布。乱数は使わないので、何度実行しても同じデータになります）。番号には主キーの索引があり、題名には索引がありません。`00-setup.sql`は空のDBで一度だけ実行します。再実行時は既存の表を消さずエラーで停止します。

## SQLを手で試す

```sh
docker compose exec db psql -X -U postgres -d reading_map
```

psqlに入り、本にあるSQLを入力します。終了は `\q` です。

## 第1章をまとめて実行する

```sh
docker compose exec -T db psql -X -U postgres -d reading_map -a -f /lab/sql/01/01-observe.sql > results/local-chapter01.txt
```

`results/local-chapter01.txt`を開くと、SQLと実行結果を確認できます。実行に失敗した場合は終了コードが0以外になります。バージョン・設定・件数・索引の状態も先頭に記録します。

掲載用に採った実行結果は [results/chapter01-million-2026-09-23.txt](results/chapter01-million-2026-09-23.txt)、測定条件は [results/README.md](results/README.md) にあります。実行時間は環境やキャッシュ状態で変わります。ミリ秒の一致ではなく、処理方法と行数を比べてください。

## 第2章：LIMITで止まる場合と止まらない場合

第1章のデータをそのまま使い、題名索引を作る前に実行します。

```sh
docker compose exec -T db psql -X -U postgres -d reading_map -a -f /lab/sql/02/01-observe.sql > results/local-chapter02.txt
```

本42、本999999、存在しない本で比較します。観察SQLは接続ごとに並列実行とJITを無効にし、work_memを4MBにします。第2章だけsynchronize_seqscansを無効にして、終了時に戻します。

第1章で本100万冊・記録200万件を用意するので、第2章で本を追加したり、第7章で記録を作り直したりする必要はありません。旧版の1,000冊で準備済みの場合は、下記の「やり直し」を実験データを消してよいときにだけ行ってください。既存データを残す場合は別の空のDBでセットアップします。

## 中断・再開・やり直し

中断は `docker compose stop`、再開は `docker compose up -d --wait`。データは専用ボリュームに残ります。

第1章の最初からやり直す場合だけ、次を実行します。**このCompose環境の実験データを削除します。**

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

まだ表を作っていない場合だけ、`00-setup.sql`を実行してください。

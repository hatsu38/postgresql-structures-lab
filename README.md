# いつものSQLで学ぶデータ構造とアルゴリズム — 実験環境

Zennの本 `postgresql-structures-explain` に対応する実験用リポジトリです。現在は第1章の環境・SQL・実行結果を収録しています。第2〜12章のSQLは今後追加します。

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
docker compose exec -T db psql -X -U postgres -d reading_map -f /lab/sql/01/02-check.sql
```

初期データは本1,000冊、読了記録2万件です。番号には主キーの索引があり、題名には索引がありません。`00-setup.sql`は空のDBで一度だけ実行します。再実行時は既存の表を消さずエラーで停止します。

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

掲載用に採った実行結果は [results/chapter01-2026-09-22.txt](results/chapter01-2026-09-22.txt)、測定条件は [results/README.md](results/README.md) にあります。実行時間は環境やキャッシュ状態で変わります。ミリ秒の一致ではなく、処理方法と行数を比べてください。

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

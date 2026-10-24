# 新しい本・第1章の実測

題名検索の結果、EXPLAIN、EXPLAIN ANALYZEを、一つの新しいDBで確認した。旧原稿の測定値を今回の結果として流用していない。これは第1章の試作のための確認であり、全11章の実験条件を確定するものではない。

## 環境と入力

- PostgreSQL 18.6、Debian、aarch64。Dockerイメージは `postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`。
- 既存labのコンテナを使わず、専用の一時コンテナ `codex-pg-sql-internals-ch1` に空のreading_mapを作った。ホストへのポート公開と既存ボリュームの接続はしていない。
- [setup.sql](setup.sql)はlabの `sql/01/00-setup.sql` をそのままコピーしたもの。SHA-256は `9edb7ba8b2a9f847da3c37e27e9070d1473c95828a3db3b413390a55e5012ee1`。
- 本100万冊、偏り付き読書記録200万件。題名Indexなし、books_pkeyのみ。セットアップ末尾にANALYZEを実行。
- en_US.utf8、libc。shared_buffers=128MB、block_size=8192、work_mem=4MB、hash_mem_multiplier=2、並列実行とJITは無効。実値は [observe.log](observe.log) に保存。

## 実行順とログ

1. [setup.sql](setup.sql)で作成し、[setup.log](setup.log)に出力した。
2. [observe.sql](observe.sql)で設定・件数・Indexを記録した。
3. 題名「実験用の本 42」のSELECT、EXPLAIN、EXPLAIN (ANALYZE, BUFFERS)を順に実行した。

```sh
docker run --detach --rm --name codex-pg-sql-internals-ch1 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec codex-pg-sql-internals-ch1 pg_isready -U postgres -d reading_map
```

接続を受け付ける状態になってから、以下をリポジトリのルートで実行する。起動直後にpg_isreadyが失敗した場合は、準備が完了してから再確認する。

```sh
docker exec -i codex-pg-sql-internals-ch1 psql -X -U postgres -d reading_map -a \
  < sql-internals/verification/ch02/explain/setup.sql
docker exec -i codex-pg-sql-internals-ch1 psql -X -U postgres -d reading_map -a \
  < sql-internals/verification/ch02/explain/observe.sql
```

再実行の出力を保存するときは別名を使い、今回のログを上書きしない。終了後は、この実験で作ったコンテナを停止する。--rmでコンテナと専用の匿名ボリュームが削除される。

```sh
docker stop codex-pg-sql-internals-ch1
```

## 確認できたこと

- 本42が1件返った。計画はSeq Scan＋Filter。
- 推定rows=1、実際のrows=1.00、loops=1、Rows Removed by Filter=999999。
- cost=0.00..19853.00、actual time=0.157..44.532、Planning Time=0.019 ms、Execution Time=44.543 ms。
- 今回は1回の観察。件数確認とSELECTを先に実行しており、コールドキャッシュや速度の比較実験ではない。

## 第1章の確認範囲

SQLの結果・計画・実測の観察を行った。書き換えはビューの役割を説明するだけで、ビューを作る実験は含めていない。図は主な段階を示す説明用のもので、内部データ構造や呼び出し順の網羅を意図しない。

Zenn CLI 0.5.4のプレビューで、二つの章の登録、第1章の本文・表・Mermaid図の描画を確認した。表紙は未作成のため、本の一覧画面にはカバー画像の注意が出る。公開設定はfalseのまま。測定用の一時コンテナは確認後に停止・削除した。

# booksで共有バッファの再利用を確認する

第5章の観察用テーブルを廃止し、第4章と同じbooksと題名Indexで測定した。既存のデータベースは使わず、専用コンテナに本100万冊・読書記録200万件を作成した。setup.sqlはsql-internals/verification/ch03/books/setup.sqlのコピー。

## 環境と再現手順

PostgreSQL 18.6、Debian、aarch64。block_size=8192、shared_buffers=128MB、work_mem=4MB。並列実行とJITは無効。ホストへのポート公開なし。

```sh
docker run --detach --rm --name codex-pg-ch05-books \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec codex-pg-ch05-books pg_isready -U postgres -d reading_map
```

接続可能になった後、このディレクトリで実行する。保存済みログを上書きしない。

```sh
docker exec -i codex-pg-ch05-books psql -X -U postgres -d reading_map -a < setup.sql
docker exec -i codex-pg-ch05-books psql -X -U postgres -d reading_map -a < observe.sql
docker stop codex-pg-ch05-books
```

observe.sqlで題名Indexを作り、CHECKPOINT後にpg_buffercache_evict_relationを使ってbooksとbooks_title_idxのページを共有バッファから外した。どちらもbuffers_skipped=0。OSキャッシュは空にしていない。

## 結果

「実験用の本 42」を探す同じSQLを2回実行した。どちらもbooks_title_idxを使うIndex Scanとなり、レコードを1件返した。

| 実行 | Index ScanのBuffers |
| --- | --- |
| 1回目 | shared read=4 |
| 2回目 | shared hit=4 |

Indexとテーブルの両方のページを含む。PlanningのBuffersは本文の抜粋には含めていない。本文では時間を比較せず、ページの読み込みと再利用の違いを説明する。hit・readの値は実行前のキャッシュの状態によって変わる。

入力と全出力はsetup.sql・setup.log、observe.sql・observe.logに保存した。測定後に専用コンテナを停止し、--rmによってコンテナと匿名ボリュームを削除した。

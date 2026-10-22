# 第9章：読書記録5件の集計計画の実測記録

2026-10-15に実施。本文の小さな例（記録の本番号 2→1→2→4→2）をそのまま一時テーブルに入れ、HashAggregateとGroupAggregateの計画を同じSQLで観察した。掲載値はsmall.logから抜粋した。

## 環境

- 専用の一時コンテナ：`claude-pg-ch9-small-20261015`。ポート公開なし、既存ボリュームの接続なし。実行後に停止・削除。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`（PostgreSQL 18.6、Debian 18.6-1.pgdg13+2、aarch64）
- max_parallel_workers_per_gather=0、jit=off、work_mem=4MB。
- 一時テーブル `records_sample`（book_id）。第8章の小さな例と同じ名前で、本物の `reading_records` と名前を分けた。
- `EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)` で、件数だけが見える短い計画にした。

## 再現手順

```sh
docker run --detach --rm --name claude-pg-ch9-small-20261015 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec -i claude-pg-ch9-small-20261015 psql -X -a -U postgres -d reading_map < small.sql > small.log 2>&1
docker stop claude-pg-ch9-small-20261015
```

## 確認した結果

| 観察 | 結果 |
| --- | --- |
| 集計結果 | 本1は1件、本2は3件、本4は1件。入力5件、結果3グループ |
| 設定なし | HashAggregate が選ばれた。`Group Key: book_id`、`rows=3.00`、下の Seq Scan は `rows=5.00`。`Batches: 1 Memory Usage: 32kB` |
| GroupAggregate | enable_hashagg=off で `GroupAggregate` の下に `Sort`（Sort Key: book_id、quicksort 25kB）。結果は同じ3グループ |
| 10・30・50・NULL | count(*)=4、count(minutes)=3、sum=90、avg=30 |
| NULLだけの1件 | count(*)=1、count(minutes)=0、sum/avg=NULL |

読書記録200万件の実測（736,097グループ、推定75,970、GroupAggregateの external merge）は `../ch08-20261004/` の記録を引き続き使う。

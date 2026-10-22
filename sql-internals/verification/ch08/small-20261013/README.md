# 第8章：本3冊・読書記録4件の結合計画の実測記録

2026-10-13に実施。本文の小さな例（本1「星」・2「海」・4「森」、記録の本番号 2→1→2→4）をそのまま一時テーブルに入れ、Nested Loop・Hash Join・Merge Joinの計画を同じSQLで観察した。掲載値はsmall.logから抜粋した。

## 環境

- 専用の一時コンテナ：`claude-pg-ch8-small-20261013`。ポート公開なし、既存ボリュームの接続なし。実行後に停止・削除。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`（PostgreSQL 18.6、Debian 18.6-1.pgdg13+2、aarch64）
- max_parallel_workers_per_gather=0、jit=off、work_mem=4MB。
- 一時テーブル `books_sample`（id主キー・title）と `records_sample`（book_id）。本物の `books`・`reading_records` とは名前を分け、読者の環境で名前が重ならないようにした。
- `EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF)` で、件数と繰り返し回数だけが見える短い計画にした。

## 再現手順

```sh
docker run --detach --rm --name claude-pg-ch8-small-20261013 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec -i claude-pg-ch8-small-20261013 psql -X -a -U postgres -d reading_map < small.sql > small.log 2>&1
docker stop claude-pg-ch8-small-20261013
```

## 確認した結果

| 観察 | 結果 |
| --- | --- |
| 結合結果 | 2「海」、1「星」、2「海」、4「森」の4件。表8.2と一致 |
| 設定なし | Hash Join が選ばれた。Hash の下は books_sample（3件） |
| Nested Loop（Seq Scan） | 内側 Materialize が `rows=2.00 loops=4`、`Rows Removed by Join Filter: 4` |
| Nested Loop（Index） | enable_seqscan=off で内側が `Index Scan using books_sample_pkey`、`rows=1.00 loops=4`、`Index Searches: 4`。外側に `Disabled: true` が付く |
| Hash Join | `Hash` の下に books_sample、`Buckets: 1024 Batches: 1 Memory Usage: 9kB` |
| Merge Join | 両側に `Sort`（Sort Key: r.book_id / b.id、quicksort 25kB） |

1週間分499,998件の実測（loops=499998、Batches: 16、external merge）は `../ch07-20261004/` の記録を引き続き使う。

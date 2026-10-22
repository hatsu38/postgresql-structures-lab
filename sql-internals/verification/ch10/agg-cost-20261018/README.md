# 第10章：読書記録5件の集計でHashAggregateとGroupAggregateのcostを比べる

2026-10-18に実施。第9章の章末が投げた「5件の例でHashAggregateが選ばれたのは何をもとにか」に、第10章で答えるための材料。第9章の小さな例（本番号 2→1→2→4→2）を同じ一時テーブルに入れ、`EXPLAIN`（cost付き）で2つの集計方法のcostを取った。

## 環境

- 専用の一時コンテナ：`claude-pg-ch10-agg-20261018`。ポート公開なし、既存ボリュームの接続なし。実行後に停止・削除。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`（PostgreSQL 18.6、`ch09-small-20261015` と同じ）
- max_parallel_workers_per_gather=0、jit=off、work_mem=4MB。

## 再現手順

```sh
docker run --detach --rm --name claude-pg-ch10-agg-20261018 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec -i claude-pg-ch10-agg-20261018 psql -X -a -U postgres -d reading_map < agg-cost.sql > agg-cost.log 2>&1
docker stop claude-pg-ch10-agg-20261018
```

## 確認した結果

| 計画 | total cost | 内訳 |
| --- | ---: | --- |
| Seq Scan on records_sample | 1.05 | 1ページ × seq_page_cost 1 ＋ 5件 × cpu_tuple_cost 0.01 |
| HashAggregate（設定なしで選ばれる） | 1.10 | Seq Scan 1.05 の上に集計 |
| GroupAggregate（enable_hashagg=off） | 1.18 | Seq Scan 1.05 → Sort 1.12 → 集計 |

統計は relpages=1、reltuples=5、book_id の n_distinct=-0.6（5件 × 0.6 = 3種類）、most_common_vals={2}、freqs={0.6}。推定 rows=3 はこの n_distinct から来ている。

GroupAggregate は本番号順に並べる Sort が要る分だけ cost が大きく、設定なしでは cost の小さい HashAggregate が選ばれた。

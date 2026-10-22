# 第10章：猫の血液型テーブル cats での統計・cost・統計更新の実測記録

2026-10-18に実施。第10章の題材を実験用ラベル（popular・rare）から猫の血液型（A型9,000匹・B型1,000匹）へ置き換えるため、`ch09-20261004/observe.sql` と同じ手順を `cats(id, blood_type)` で取り直した。本文の `cats` の数値はこのログから引用する。読書記録200万件の集計の見積もり（n_distinct 77,812・実測736,097）は `ch09-20261004` の値を引き続き使う。

## 環境

- 専用の一時コンテナ：`claude-pg-ch10-cats-20261018`。ポート公開なし、既存ボリュームの接続なし。実行後に停止・削除。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`（PostgreSQL 18.6、Debian 18.6-1.pgdg13+2、aarch64）
- max_parallel_workers_per_gather=0、jit=off、work_mem=4MB、default_statistics_target=100、block_size=8192。cost の設定は既定値（seq_page_cost=1、random_page_cost=4、cpu_tuple_cost=0.01、cpu_index_tuple_cost=0.005、cpu_operator_cost=0.0025）。
- 主データ（books・reading_records）は作っていない。`cats` だけを `BEGIN` の中で作り、最後に `ROLLBACK` した。

## 再現手順

```sh
docker run --detach --rm --name claude-pg-ch10-cats-20261018 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec -i claude-pg-ch10-cats-20261018 psql -X -a -U postgres -d reading_map < observe.sql > observe.log 2>&1
docker stop claude-pg-ch10-cats-20261018
```

## 確認した結果（旧 stats_demo との比較）

| 観察 | cats | 旧 stats_demo（2026-10-04） |
| --- | ---: | ---: |
| A型（popular）の Seq Scan の total cost | 189.00 | 189.00 |
| B型（rare）の Index Scan の total cost | 35.78 | 35.78 |
| A型を Index Scan で読む cost | 258.79 | 258.79 |
| relpages / reltuples | 64 / 10000 | 64 / 10000 |
| width | 6 | 11 |
| UPDATE 8,000件後のページ数 | 99 | 107 |
| 古い統計での推定 rows（実測 9,000） | 1547 | 1672 |
| ANALYZE 後の Seq Scan の total cost | 224.00 | 232.00 |
| id < 2500 の推定 / 実測 | 2499 / 2499 | 2499 / 2499 |

値が 'A'・'B' の1文字になって1レコードが小さくなり、更新後のページ数と、そこから補正した推定件数が変わった。cost の計算の形（64 + 100 + 25、99 + 100 + 25）は同じ。

## Index Scan の cost の内訳（index-cost.sql / index-cost.log）

同じコンテナ設定で `cats` を作り直し、Index のページ数（11）、`blood_type` の `correlation`（1）、`random_page_cost`（4）、`cpu_index_tuple_cost`（0.005）を確認した。手計算は次のとおりで、計画の値と一致する。

- B型（1,000件）: 0.285（降下 14×0.0025 + 2×50×0.0025）+ 8（Index 2ページ×4）+ 7.5（1,000×(0.005+0.0025)）+ 10（テーブル 7ページ: 4 + 6×1、correlation=1 なので min_IO）+ 10（1,000×0.01）= 35.785 → 35.78
- A型（9,000件）: 0.285 + 40（10ページ×4）+ 67.5 + 61（58ページ: 4 + 57×1）+ 90 = 258.785 → 258.79

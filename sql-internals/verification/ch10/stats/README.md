# 第9章：統計・推定件数・costの実測記録

条件に合う割合、統計、ページ数が実行計画の見積もりへどう反映されるかを確認した。本文の出力は今回の実測で、旧版の出力は引用していない。

## 環境と開始状態

- 専用一時コンテナ：`codex-pg-ch9`。ポート公開なし、既存ボリュームの接続なし。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`
- PostgreSQL 18.6、Debian 18.6-1.pgdg13+2、aarch64。version全文はprepare.log。
- DB：reading_map、datcollate/datctype：en_US.utf8、block_size：8192、shared_buffers：128MB。
- max_parallel_workers_per_gather=0、jit=off、work_mem=4MB、default_statistics_target=100。
- seq_page_cost=1、random_page_cost=4、cpu_tuple_cost=0.01、cpu_index_tuple_cost=0.005、cpu_operator_cost=0.0025、effective_cache_size=4GB。
- books100万件・reading_records200万件と、第8章までのIndexを再作成。前章の準備とそろえてpg_buffercacheも導入したが、今回使っていない。
- setup.sqlとprepare.sqlが両方完了した後に、observe.sqlを実行した。今回の主実験は、独立したstats_demoを作成して同一トランザクション内で観察する。

## ファイルと再現手順

1. `setup.sql`：共通データを生成。出力はsetup.log。
2. `prepare.sql`：Indexの作成、ANALYZE、環境の確認。出力はprepare.log。
3. `observe.sql`：stats_demoの作成、各計画と統計、cost計算、データ更新前後の比較、ROLLBACK。その後、主データのグループ数を確認。出力はobserve.log。

共通setup.sqlのSHA-256：`9edb7ba8b2a9f847da3c37e27e9070d1473c95828a3db3b413390a55e5012ee1`。

```sh
docker run --detach --rm --name codex-pg-ch9 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae

docker exec codex-pg-ch9 pg_isready -U postgres -d reading_map
```

接続可能になったら、このフォルダで各SQLを順に実行し、毎回完了を待つ。

```sh
docker exec -i codex-pg-ch9 psql -X -a -U postgres -d reading_map < setup.sql > setup.log 2>&1
docker exec -i codex-pg-ch9 psql -X -a -U postgres -d reading_map < prepare.sql > prepare.log 2>&1
docker exec -i codex-pg-ch9 psql -X -a -U postgres -d reading_map < observe.sql > observe.log 2>&1
docker stop codex-pg-ch9
```


## 確認した結果

| 対象 | 結果 |
| --- | --- |
| 初期データ | popular=9000、rare=1000。64ページ、10000件。 |
| categoryのMCV | {popular,rare}、割合{0.9,0.1}、n_distinct=2、ヒストグラムなし。 |
| popularの通常計画 | Seq Scan、cost=0.00..189.00、推定・実測9000件。 |
| rareの通常計画 | Index Scan、cost=0.29..35.78、推定・実測1000件。 |
| popularのIndex Scan候補 | cost=0.29..258.79、推定9000件。EXPLAINのみ。 |
| rareのSeq Scan候補 | cost=0.00..189.00、推定1000件。EXPLAINのみ。 |
| Seq Scanの手計算 | 64×1＋10000×0.01＋10000×0.0025＝189。SQLでも各成分64・100・25を確認。 |
| id列の統計 | 統計目標10で境界{1,1000,2000,3000,4000,5000,6000,7000,8000,9000,10000}、n_distinct=-1。 |
| id < 2500 | Seq Scan、推定・実測2499件。説明用の概算は約2500件として区別。 |
| 8000件をrareへ変更 | popular=1000、rare=9000。統計の割合は古いまま。 |
| 古い統計でrareを検索 | Index Scan、推定1672、実測9000。保存統計64ページ・10000件、現在107ページ。 |
| ページ数の補正 | 10000×107÷64×0.1≒1672。単に1000件のまま残るとは説明しない。 |
| ANALYZE後 | MCVが{rare,popular}、割合{0.9,0.1}。107ページ・10000件。Seq Scanへ変化し、推定・実測9000、cost=0.00..232.00。 |
| ROLLBACK後 | stats_demoが存在しないこと、3種のenable_*設定がonに戻ることを確認。 |
| reading_recordsの種類数 | n_distinct=77812、HashAggregateの推定rows=77812、実際の異なる本番号736097。 |

## 説明の範囲と限界

- 主実験は通常のテーブルをトランザクション内で作成し、最後にROLLBACKする。TEMP TABLEや、ソート・ハッシュの退避ファイルとは別。未コミットの新規テーブルへ他接続の自動ANALYZEは入らない。
- 1万件のMCVが正確だったことを、大規模なデータの推定にも一般化しない。章末で標本からの推定誤差を対比した。
- idのヒストグラムは等頻度。概算の約2500件と、PostgreSQLの境界補正を含む2499件を分けている。
- costの手計算は並列処理がなく、単純な比較条件が一つのSeq Scanに限定。Index・Sort・JOINは仕事の内訳を説明し、全実装式を再現したとは扱わない。
- 比較表は同じ条件での候補を比較する。popularのSeq ScanとrareのIndex Scanのcostだけを比較して、方法の一般的な優劣を決めない。
- enable_*の変更は候補観察のため。チューニングの推奨設定としては扱わない。
- 1回の実行時間から性能の優劣を決めない。主な観察対象は統計・見積もり・計画の変化。
- 第8章の推定75970と今回の77812は別のANALYZEによるもの。データと実グループ数736097は同じ。今回の標本そのものを保存・解析したわけではなく、推定誤差の全要因を特定したとは説明しない。

## 一次資料

- [pg_statsの各列](https://www.postgresql.org/docs/18/view-pg-stats.html)
- [統計と現在のページ数による補正](https://www.postgresql.org/docs/18/planner-stats.html)
- [等値条件・範囲条件の推定例](https://www.postgresql.org/docs/18/row-estimation-examples.html)
- [costとEXPLAIN](https://www.postgresql.org/docs/18/using-explain.html)
- [プランナのcost設定](https://www.postgresql.org/docs/18/runtime-config-query.html)
- [ANALYZEと標本](https://www.postgresql.org/docs/18/sql-analyze.html)
- [各処理のcost計算の実装](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/optimizer/path/costsize.c)

## 原稿と図の確認

掲載SQL36文、出力92行を実測ログと照合した。計画7件、costの手計算、更新前後の割合と件数、ROLLBACK後の状態も照合済み。図9.1は旧版のPNG・SVGを内容を変えずにコピーし、実験の件数との対応、原本との一致、catalog.jsonのハッシュを確認した。

natural-japaneseのquickモードで推敲し、lintと段落先頭文の抽出を実行した。残った語彙多様性の指摘1件は、統計・推定・件数など同じ技術用語を一貫して使うため保持した。読解負荷の指摘は0件。「まとめ」は他章との統一とユーザーの希望に合わせて保持。SQL→出力→解説の順序と、コード出力の折り返しを確認した。

Zennプレビューで第9章の表示を確認した。図9.1、costの内訳表、統計更新前後の比較表、改行した実行計画を目視確認し、章の冒頭を開いた状態にした。

ログ保存と照合の完了後、専用一時コンテナ`codex-pg-ch9`を停止した。`--rm`で作成したため、実験用DBとコンテナも削除された。

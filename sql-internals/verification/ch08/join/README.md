# 第7章：JOINの実測記録

本100万冊・読書記録200万件で実行した。掲載値はこのフォルダのobserve.logから抜粋した。旧版の測定値は引用していない。

## 環境と開始状態

- 専用の一時コンテナ：`codex-pg-ch7`。ホストへのポート公開・既存ボリュームの接続なし。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`
- PostgreSQL 18.6（Debian 18.6-1.pgdg13+2、aarch64）。正確なversion文字列はprepare.log。
- DB：reading_map、照合順序・文字種：en_US.utf8、block_size：8192、shared_buffers：128MB。
- max_parallel_workers_per_gather=0、jit=off、work_mem=4MB、hash_mem_multiplier=2、default_statistics_target=100。
- 第6章終了時のIndexを再作成：books_pkey、books_title_idx、reading_records_order_idx（finished_at DESC, book_id ASC）。pg_buffercacheも前章の状態を再現して導入し、この章では使わない。
- 計測前にVACUUM (ANALYZE)を明示的に実行。両テーブルのrelallvisibleがrelpagesと一致したことをstabilize.logに保存した。掲載計画のIndex Only ScanはHeap Fetches=0。第6章の測定時点から可視性マップの状態は変わっており、本文脚注で説明した。
- 準備完了前に始めてしまった試走の出力は採用せず、準備・VACUUM完了後にobserve.sql全体を再実行した。このフォルダのobserve.logとCSV照合結果は再実行分のみ。

## 実行順序とファイル

1. setup.sql：第6章と同一のデータ生成SQL。SHA-256は`9edb7ba8b2a9f847da3c37e27e9070d1473c95828a3db3b413390a55e5012ee1`。出力はsetup.log。
2. prepare.sql：Indexの作成、環境・件数の記録。出力はprepare.log。
3. stabilize.sql：VACUUM (ANALYZE)と可視性マップの状態確認。出力はstabilize.log。
4. observe.sql：最新20件、通常の週検索、方式を指定したNested Loop・Hash Join・Merge Join、work_memだけを64MBに変えたHash Join。出力はobserve.log。
5. check-results.py：全結果を結合前の記録と照合する。出力はcheck-results.log。
6. small.sql：説明用の3冊・4記録と、重複キー2×3＝6組を確認。出力はsmall.log。

再現するときは、専用コンテナを起動して接続可能になってから、上の順序で完了を待って実行する。

```sh
docker run --detach --rm --name codex-pg-ch7 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae

docker exec codex-pg-ch7 pg_isready -U postgres -d reading_map
```

このディレクトリから、各SQLを順番に次の形式で実行する（例はsetup）。

```sh
docker exec -i codex-pg-ch7 psql -X -a -U postgres -d reading_map < setup.sql > setup.log 2>&1
```

observe.sqlのCOPYは各方式の結果をコンテナ内の`/tmp/ch07-*.csv`に保存する。すべてのSQL実行と照合が済んでからコンテナを停止する。

```sh
python3 check-results.py > check-results.log
docker stop codex-pg-ch7
```

## 結果

| 実験 | 確認した処理 |
| --- | --- |
| 最新20件 | 自然にNested Loopを選択。Limitが20件、books_pkeyはrows=1.00、loops=20、Index Searches=20。Buffersは外側4、内側80、合計84。 |
| 週検索・通常設定 | 自然にHash Joinを選択。 |
| 同じ週・Nested Loop | books_pkeyのIndex Searches=499998、loops=499998。内側のshared hit=1999992。 |
| 同じ週・Hash Join、4MB | 本100万冊で構築、記録499998件を照合。Buckets=131072、Batches=16、Memory Usage=4952kB。全体temp read/written各7818。 |
| 同じ週・Merge Join | books_pkeyを本番号順で読み、記録499998件を本番号順へSort。external merge、Disk=12728kB。MaterializeのMaximum Storage=260kB。 |
| 同じ週・Hash Join、64MB | Batches=1、Memory Usage=70692kB。tempなし。hash_mem_multiplierは2のまま。 |

三方式とHash Joinの64MB版で、返った499998件の本番号・題名・日時が、結合前の全記録から独立に組み立てた期待値と一致した。Counterで重複も比較し、順序は比較対象外にした。日時はこのデータ内で一意。最新20件は題名・日時・本番号と順序を確認した。

4組の週検索結果を行順で正規化したSHA-256はすべて`49b7a0fa502dd46db73d7942e58bb6b73f21df45b8fe70f00e8fa9fa049c9476`。実際の全件CSVは一時コンテナ内だけに置き、リポジトリには保存しない。対象週の本の種類は255238で、記録499998件をまとめて減らしていないことも確認した。

## 比較の条件と限界

JOIN方式の比較はwork_mem=4MBで統一し、取得列・期間・Index・データを変更していない。enable_memoize=offは全方式で共通とし、Nested Loopの検索結果再利用を除いて基本の繰り返しを観察した。設定はSET LOCALで変更し、各回ROLLBACKで復元。ログ末尾でwork_mem=4MBと4個のenable設定がonへ戻ったことを確認している。

計画とCOPYは別々の実行。同一の静的データと設定を使う。時間・Buffersは実行順序やキャッシュ状態に影響されるので、この一連の測定から一般的な速度順位は示さない。ANALYZEの標本抽出でcostや推定件数も変わり得る。

64MB版は同じHash Joinのメモリ不足の有無を見る追加実験で、三方式の時間比較に混ぜない。Batches=16は16回の全表走査を意味せず、両入力を対応する区分に分けて処理する。ハッシュ表の予算はwork_mem×hash_mem_multiplierであり、SQL全体の厳密な使用上限ではない。

## 参照した一次資料

- [PostgreSQL 18：三つの結合方式](https://www.postgresql.org/docs/18/planner-optimizer.html)
- [EXPLAIN：rows、loops、Hash、Sort、Materialize](https://www.postgresql.org/docs/18/using-explain.html)
- [work_memとhash_mem_multiplier](https://www.postgresql.org/docs/18/runtime-config-resource.html)
- [計画方式とMemoizeの設定](https://www.postgresql.org/docs/18/runtime-config-query.html)
- [Hash Joinの実装とバッチ分割](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/executor/nodeHashjoin.c)

## 原稿・図の確認

本文に抜粋した実行計画34行と掲載SQL12文がobserve.logに一致することを確認済み。図は説明用であることを明記し、新規3枚と旧版からコピーした1枚のPNG・SVGを確認する。数値入りの旧版実測図は再利用しない。原本と来歴はimages/postgresql-sql-internals/catalog.jsonおよび同READMEへ記録する。

自然な日本語のlintを実行し、不要な接続句と対比を修正した。最終指摘は語彙の反復のみで、本番号・記録・Indexなどの技術用語を一貫させるため維持した。

Zennプレビューで章の登録、冒頭、図の参照、表、太字の表示を確認した。専用コンテナは検証後に停止し、--rmにより削除済み。

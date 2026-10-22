# 第8章：集計の実測記録

2026-10-04に実施。HashAggregateとGroupAggregateを同じSQL・データで比べ、Pythonで独立に数えた本ごとの件数とも照合した。本文の測定値は今回のログを使用し、旧版の出力は引用していない。

## 環境と開始状態

- 専用一時コンテナ：codex-pg-ch8-20261004。ポート公開なし、既存ボリュームの接続なし。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`
- PostgreSQL 18.6、Debian 18.6-1.pgdg13+2、aarch64。version全文はprepare.log。
- DB：reading_map、datcollate/datctype：en_US.utf8、block_size：8192、shared_buffers：128MB、default_statistics_target：100。
- max_parallel_workers_per_gather=0、jit=off、work_mem=4MB、hash_mem_multiplier=2。
- 第7章までのIndex：books_pkey、books_title_idx、reading_records_order_idx（finished_at DESC, book_id ASC）。前章の状態を再現してpg_buffercacheも導入したが、今回使っていない。
- 測定前にVACUUM (ANALYZE)。データ生成、Index作成、保守処理を順に完了してから観察した。

## ファイルと再現手順

1. setup.sql：共通データを生成。books100万件、reading_records200万件。出力setup.log。
2. prepare.sql：Index・環境・件数を確認。出力prepare.log。
3. stabilize.sql：VACUUM (ANALYZE)とページの状態確認。出力stabilize.log。
4. observe.sql：通常のHashAggregate、enable_hashagg=offでのGroupAggregate。同じSQLでEXPLAINと結果のCSV保存。出力observe.log。
5. small.sql：5件の小例、SUM・AVG・NULL、同じ1万件でグループ数を変えた比較。出力small.log。
6. check-results.py：結合などを行わず、元のbook_id200万件を取り出してPythonのCounterで数える。両方式のCSVをこの独立した期待値に照合。出力check-results.log。

共通setup.sqlのSHA-256：`9edb7ba8b2a9f847da3c37e27e9070d1473c95828a3db3b413390a55e5012ee1`。

```sh
docker run --detach --rm --name codex-pg-ch8-20261004 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae

docker exec codex-pg-ch8-20261004 pg_isready -U postgres -d reading_map
```

接続可能になったら、このフォルダから各SQLを上の順番に実行し、毎回完了を待つ。次はsetupの実行例。

```sh
docker exec -i codex-pg-ch8-20261004 psql -X -a -U postgres -d reading_map < setup.sql > setup.log 2>&1
```

全SQL実行後、CSVがコンテナ内にある間に照合する。

```sh
python3 check-results.py > check-results.log
docker stop codex-pg-ch8-20261004
```

COPYはコンテナ内の/tmp/ch08-hash.csvと/tmp/ch08-group.csvに保存する。CSVはリポジトリには残さない。small.sqlのTEMPテーブルは同一接続内で作成・比較・削除する。

## 確認した結果

| 対象 | 結果 |
| --- | --- |
| 小例2・1・2・4・2 | 本1=1件、本2=3件、本4=1件。入力5、結果3グループ。 |
| 10・30・50・NULL | count(*)=4、count(minutes)=3、sum=90、avg=30。 |
| NULLだけの1件 | count(*)=1、count(minutes)=0、sum/avg=NULL。 |
| 集計対象0件、GROUP BYなし | count(*)=0、sum/avg=NULL。補助確認。 |
| 200万件・HashAggregate | 結果736097、推定75970。Batches=21、Memory Usage=8257kB、Disk Usage=27752kB、temp read=4090 written=6731。 |
| 200万件・GroupAggregate | 同じ736097グループ。入力200万件をSort、external merge、Disk=23528kB。 |
| 1万件・10グループ | HashAggregate、Batches=1、Memory Usage=32kB。各グループ1000件。 |
| 1万件・1万グループ | HashAggregate、Batches=1、Memory Usage=793kB。各グループ1件。 |

全データの両方式で、本番号ごとの件数がPythonのCounterと完全一致した。グループの重複がないこと、グループ数736097、全カウントの合計2000000も確認した。本100万冊のうち263903冊には記録がなく、このGROUP BYの結果には現れない。

本番号順に正規化した集計結果のSHA-256は両方式とも`d10846bdbcb029692ad988c2e50bab4f52cc9855a76285e20bff2a5d9a0a0d45`。SQLにはORDER BYがないため、返す順序は比較しない。

## 比較の条件と限界

- HashAggregateとGroupAggregateは同じ取得列・全期間・データ・Index・work_memで測定。変更はSET LOCAL enable_hashagg=offだけ。ROLLBACK後のonとwork_mem=4MBを確認した。
- EXPLAINとCOPYは別の実行。同一の静的データ・設定で行った。
- 1万件の比較は同じinteger型・同じ入力件数・COUNT(*)・work_mem=4MB。観察対象はグループ数とメモリ。実行時間の差を一般化しない。TEMPテーブルなので、ログのlocal Buffersは一時テーブル用のページであり、退避用のtempとは区別する。本文ではこの比較のBuffersを省略した。
- グループの保持量はCOUNTの小例。集計関数や型によって状態の大きさは変わる。GroupAggregate全体のメモリを定数と説明せず、Sortの準備を分けて説明した。
- 本文のBatches=21は、最初のメモリ集計と後から読み戻したバッチの合計。21回の全表走査ではない。新規グループの入力を退避し、既存グループの状態を更新し続ける説明はPG18のnodeAgg.c冒頭「Spilling To Disk」で確認した。
- 8MBのハッシュ予算は、表示値を必ず8192kB以下にする厳密な上限として扱わない。実測は8257kB。超過分の具体的な内訳は調査していないので断定しない。
- 統計の標本・キャッシュ状態などでcost・推定値・時間は変わる。一回の実行時間から方式の優劣を決めない。

## 一次資料

- [COUNT・SUM・AVGとNULL](https://www.postgresql.org/docs/18/functions-aggregate.html)
- [集計の途中の状態と最終結果](https://www.postgresql.org/docs/18/xaggr.html)
- [ハッシュ集計と退避の実装](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/executor/nodeAgg.c)
- [work_memとhash_mem_multiplier](https://www.postgresql.org/docs/18/runtime-config-resource.html)
- [enable_hashagg](https://www.postgresql.org/docs/18/runtime-config-query.html#GUC-ENABLE-HASHAGG)

## 原稿と図の確認

本文に掲載した出力33行、SQL16文がログにあることを確認した。新規図2枚と旧版からコピーした1枚のPNG・SVGを目視確認し、catalog.jsonへ出典・ハッシュを記録した。コピーした退避の図は2・1・2・3・2へ小例が変わることを本文で明示している。

Zennのプレビューで見出し・表・図3枚の表示を確認した。画像の参照先、catalogのPNG・SVGのハッシュ、コピーした図と原本の一致、共通setup.sqlのハッシュも確認済み。

natural-japaneseのquickモードで推敲した。「このように」の重複を除き、前章への参照を整理した。残った語彙多様性の警告は技術名を一貫して使うため保持。文頭「は、」の重複判定はインラインコードの除外によるもので、実際には異なる用語の説明なので保持した。

ログ保存と照合の完了後、専用一時コンテナcodex-pg-ch8-20261004を停止した。--rmで作成したため、実験用DBとコンテナ内の一時CSVも削除された。

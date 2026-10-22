# 第6章：上位取得とIndexの実測（2026-10-04）

第5章と同じ対象週の全件ソート、LIMIT 20付きのtop-N、日時順Indexを作った後のLIMIT 20を、専用DBで実行した。過去の26kBという記録の転記ではなく、3方式を今回測り直した。

## 環境・開始状態

- PostgreSQL 18.6（Debian 18.6-1.pgdg13+2）、aarch64。版・DB・照合順序はprepare.logに記録。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`。
- コンテナ：`codex-pg-ch6-20261004`。ホストへのポート公開なし。既存DB・ボリュームは使用しない。
- DB reading_map、en_US.utf8、block_size=8192、shared_buffers=128MB、default_statistics_target=100。
- max_parallel_workers_per_gather=0、jit=off。比較中のwork_memはすべて64MB。
- 共通のbooks 100万冊、reading_records 200万件。対象週は2026-09-14以上、2026-09-21未満の499,998件。日時は全件で一意。
- 初期Indexはbooks_pkeyとbooks_title_idxのみ。reading_recordsにはIndexなし。第4章終了状態に合わせてpg_buffercache拡張を用意したが、今回の測定では使わない。
- setup.sql・prepare.sqlは第5章と同じ。setup.sqlのSHA-256は`9edb7ba8b2a9f847da3c37e27e9070d1473c95828a3db3b413390a55e5012ee1`。

## 入力とログ

| 入力 | 出力 | 用途 |
| --- | --- | --- |
| [setup.sql](setup.sql) | [setup.log](setup.log) | 共通データの作成とANALYZE |
| [prepare.sql](prepare.sql) | [prepare.log](prepare.log) | 第5章終了時の状態を再現、版・設定・Index・件数を確認 |
| [observe.sql](observe.sql) | [observe.log](observe.log) | 全件ソート、top-N、結果出力、Index作成とANALYZE、Index利用の計画と結果、設定復元 |
| [check-results.py](check-results.py) | [check-results.log](check-results.log) | 全件ソートの先頭20件と、top-N・Indexの結果を比較 |

全件ソートとtop-Nの間にANALYZEは挟んでいない。Index作成後はANALYZEを実行したため、推定rowsは508,007から504,342へ変わった。本文で、推定と今回実際に返した件数を区別している。

## 測定結果

| 観察点 | 全件ソート | top-N | Index利用 |
| --- | --- | --- | --- |
| 主な計画 | Seq Scan→Sort | Seq Scan→Sort→Limit | Index Only Scan→Limit |
| Sort Method | quicksort | top-N heapsort | Sortなし |
| Sort Memory | 27,913kB | 26kB | Sortなし |
| Seq Scanの出力 | 499,998件 | 499,998件 | Seq Scanなし |
| Seq Scanの除外 | 1,500,002件 | 1,500,002件 | Seq Scanなし |
| 検索結果 | 499,998件 | 20件 | 20件 |
| Heap Fetches | 対象外 | 対象外 | 20 |
| 実行部分の最上段Buffers | shared hit=10817 | shared hit=10811 | shared hit=23 |

Indexの計画にSortはない。Index Condに対象期間があり、Index Only Scanのactual rowsは20。Index Only Scanの推定rows=504342は対象範囲を最後まで読んだ場合の推定であり、今回の出力件数ではない。

全件ソートの上段sharedは、子のSeq Scanの10811より6多い。本文の全件ソートとtop-Nの抜粋ではBuffersを省き、入出力件数とMemoryの比較に絞った。Index利用の上下にあるshared hit=23は加算しない。ページ取得数をレコード数と同一視しない。

データ作成後、件数確認→全件ソート→top-N→各結果のCOPY→Index作成→Index利用という順序で測定した。キャッシュを厳密に統制した速度比較ではない。本文では実行時間の倍率や、全条件でIndexが最速だという結論を出していない。

## 結果の検証

両列をCSVへ全件出力し、全件ソートが499,998件、top-NとIndex利用が各20件であることを確認した。それぞれの出力について全件の日時範囲とfinished_at DESC・book_id ASCの順序を検査した。

全件ソートの先頭20行と、top-N・Index利用のCSVは、バイト単位で完全に一致した。内容・重複・順序も一致する。

- 全件のSHA-256：`15a7420fba832df635666b01e5fe34eb53735a0c287b5044c224ad0f55fd7633`。第5章の全件結果とも一致。
- 20件のSHA-256：`5bed60c89a608b8187f0627e6c6b7656eed4572d428ecbb69cc6f4bda256bcb9`。
- 先頭：本758963・2026-09-20 23:59:59。
- 20件目：本816337・2026-09-20 23:59:36。

本文のSQL8文、掲載出力18行をobserve.logへ照合した。Zennプレビューで見出し、図、コード枠の表示を確認した。実装では一定の入力を受け取ってからbounded heapへ切り替える点を公式ソースで確認し、小例を実際の5件の処理トレースとして扱わない旨を補足した。

## 図

2枚とも旧版からPNG・SVGを変更せずコピーした。top-three-heapは合意した8・3・5・9・2の例と一致する。08-top-n-vs-indexの「持つ なし」は候補を選ぶヒープが不要という意味であること、上側の9・8・5はヒープ配置を表さないことをキャプションに記載した。

旧版08-sort-vs-topnは64MBと4MBを比較しているため、同じ64MBの今回の説明には使わず、表6.2へ今回の実測を掲載した。

## 再現方法

リポジトリのルートから実行する。同名のコンテナがすでにある場合はその用途を確認し、別名を使う場合はcheck-results.pyのcontainerも変更する。

```sh
docker run --detach --rm --name codex-pg-ch6-20261004 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec codex-pg-ch6-20261004 pg_isready -U postgres -d reading_map
```

pg_isreadyが接続可能を返した後、次の順で実行する。既存ログを上書きしない。

```sh
for chapter_step in setup prepare observe; do
  docker exec -i codex-pg-ch6-20261004 psql -X -U postgres -d reading_map -a \
    < "_drafts/postgresql-sql-internals/verification/ch06-20261004/${chapter_step}.sql" || break
done
python3 _drafts/postgresql-sql-internals/verification/ch06-20261004/check-results.py
```

## 終了状態

work_memを4MBへ戻した。booksの主キー・題名Indexに加え、reading_records_order_idx(finished_at DESC, book_id ASC)を残す。これが第7章以降の開始状態になる。主データの更新は行っていない。

検証用のCSVはコンテナ内の/tmpだけに保存した。検証後、専用コンテナは停止済み。`--rm`により匿名ボリュームとCSVも削除された。読者の環境で日時Indexを削除する手順は、本文には加えていない。

```sh
docker stop codex-pg-ch6-20261004
```

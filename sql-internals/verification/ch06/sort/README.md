# 第5章：ソートの実測

新構成の第5章を執筆するため、同じ対象週の499,998件を、work_mem=64MBと64kBで並べた。掲載値は今回の実行結果であり、旧版の測定値の転記ではない。

## 環境と開始状態

- PostgreSQL 18.6（Debian 18.6-1.pgdg13+2）、aarch64。実際のversion()出力はprepare.logに保存。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`。
- 専用コンテナ：`codex-pg-ch5`。ホストへのポート公開なし。既存のDB・ボリュームは使っていない。
- DB：reading_map、照合順序・文字種：en_US.utf8。
- block_size=8192、shared_buffers=128MB、基準work_mem=4MB、default_statistics_target=100。
- max_parallel_workers_per_gather=0、jit=off。比較中にANALYZEを実行していない。
- booksは100万冊、reading_recordsは200万件。日時は全件異なる。対象週は2026-09-14以上、2026-09-21未満。
- 第4章終了時に合わせて、books_pkeyとbooks_title_idxだけを用意。reading_recordsにIndexはなく、books_observationもない。pg_buffercache拡張は残る状態を再現したが、この章の測定では使っていない。
- setup.sqlは第4章と同一。SHA-256：`9edb7ba8b2a9f847da3c37e27e9070d1473c95828a3db3b413390a55e5012ee1`。

## 実行順とログ

| 入力 | 出力 | 用途 |
| --- | --- | --- |
| [setup.sql](setup.sql) | [setup.log](setup.log) | 共通データを生成しANALYZE |
| [prepare.sql](prepare.sql) | [prepare.log](prepare.log) | 開始状態を再現し、版・設定・Index・件数を記録 |
| [observe.sql](observe.sql) | [observe.log](observe.log) | 対象件数、64MBと64kBの実行計画、4MBへの復元 |
| [trace.sql](trace.sql) | [trace.log](trace.log) | 64kBでの列の生成数と合流段階を追加観察 |
| [check.sql](check.sql) | [check.log](check.log) | 両設定で全結果をCSVへ出力し、設定・Indexの終了状態を確認 |
| [check-results.py](check-results.py) | [check-results.log](check-results.log) | 全件の日時範囲・並び順・件数・出力一致を検証 |

本文では読み進めやすいようにSETを使い、最後に4MBへ戻す。検証用のtraceと結果比較にはSET LOCALを使い、ROLLBACKで設定を戻した。主データへの更新はない。

## 結果

| 観察点 | 64MB | 64kB |
| --- | --- | --- |
| Sort Method | quicksort | external merge |
| 作業領域の表示 | Memory: 27913kB | Disk: 12784kB |
| Sortのtemp | 表示なし | read=6367 written=6793 |
| Seq Scanのshared | hit=10811 | hit=10811 |
| Seq Scanの実際の出力 | 499,998件 | 499,998件 |
| Seq Scanの除外 | 1,500,002件 | 1,500,002件 |
| Sortの実際の出力 | 499,998件 | 499,998件 |
| 推定rows | 497,939 | 497,939 |

64MBのSortのsharedは10,817で、子のSeq Scanの10,811より6多い。本文の64MBの抜粋では上段のBuffersを省略し、Sortの比較回数や木の段数と解釈していない。64kBでは上段・下段ともshared hit=10811であり、本文は子を含む累積値であることを説明する。

trace_sortによる追加実行では、最初に428個の列を作り、最大6個ずつ合流した。428→72→12→2とまとまりを減らし、最後の2列をマージしながら出力していた。1,598ブロック×8kB＝12,784kBでDiskと一致する。書き込み累計は6,793ブロック×8kB＝54,344kB。

件数確認のSELECTの後、64MB→64kBの順に1回ずつ測った。両測定のテーブルアクセスはすべてshared hitだが、厳密にキャッシュをそろえた速度比較ではない。本文では時間の倍率を結論にしていない。

## 内容と順序の検証

同じSELECTをそれぞれのwork_memでCOPYし、実際の出力をCSVとして取得した。両方とも499,998件で、すべて対象期間内にあること、finished_at DESC・book_id ASCの順であることを全件確認した。さらに出力のバイト列を比較し、内容・重複・順序を含めて完全に一致した。

共通SHA-256：`15a7420fba832df635666b01e5fe34eb53735a0c287b5044c224ad0f55fd7633`。

先頭は本758963・2026-09-20 23:59:59、末尾は本333366・2026-09-14 00:00:00。データは日時が一意なので、同時刻の本番号による比較は図5.1の説明用の例として区別している。

本文の掲載出力17行とSQL7文を、保存ログに照合した。省略は「…」で明示。図の3参照先とPNG・SVG原本を確認し、Zennプレビューで章の表示も確認した。新規の図5.2・5.3は6個の値を使った概念図で、PostgreSQLの6件の処理をトレースした図ではない。

## 再現方法

リポジトリのルートで専用コンテナを起動し、pg_isreadyが接続可能になるまで待つ。同名のコンテナがある場合は、その用途を確認してから別名にする。

```sh
docker run --detach --rm --name codex-pg-ch5 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec codex-pg-ch5 pg_isready -U postgres -d reading_map
```

接続可能になった後、次の順にSQLを実行する。既存の保存ログは上書きしない。

```sh
for chapter_step in setup prepare observe trace check; do
  docker exec -i codex-pg-ch5 psql -X -U postgres -d reading_map -a \
    < "sql-internals/verification/ch06/sort/${chapter_step}.sql" || break
done
python3 sql-internals/verification/ch06/sort/check-results.py
```

check-results.pyはコンテナ内のCSVを読み取る。コンテナ名を変える場合は同ファイルのcontainerも合わせる。trace.logには開発者向けの詳細な進行ログが入るため、本文には説明に必要な観察結果だけを記載した。

## 後片付け

実行後はwork_mem=4MB、booksの二つのIndexだけが残り、reading_recordsのIndex・books_observationがない状態を確認した。確認用CSVはコンテナ内の/tmpだけに保存し、リポジトリには追加していない。

検証完了後、専用コンテナは停止済み。`--rm`により、専用の匿名ボリュームとCSVも削除された。

```sh
docker stop codex-pg-ch5
```

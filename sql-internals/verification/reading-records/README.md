# 読書記録の実験

本100万冊、読書記録200万件を使い、Bitmap Scan・ソート・LIMIT・JOIN・集計・統計・Index Only Scanを確かめるためのSQLと出力です。読書記録は4週間に分かれ、各週にちょうど50万件ずつ入っています。

## 日時の割り当て

`setup.sql`では、番号nから`((n - 1) * 104729) % 2000000`を計算します。104729と2000000は互いに素なので、0から1,999,999までが重複せずに現れます。その値に28日分の秒数2,419,200を掛けて2,000,000で割り、整数同士の除算で秒未満を切り捨ててから、2026年8月24日0時に足します。

50万件ごとに7日分になるため、各週がちょうど50万件になります。時刻は保存順に並ばず、200万件の日時はすべて異なります。9月20日の1日分は71,428件です。

## 測定環境

- PostgreSQL 18.6（Debian 18.6-1.pgdg13+2）、Dockerの専用コンテナ。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`
- `shared_buffers=128MB`、`block_size=8192`、`hash_mem_multiplier=2`、`default_statistics_target=100`。
- 各接続で`max_parallel_workers_per_gather=0`、`jit=off`、通常は`work_mem=4MB`。ソートとLIMITの比較では64MB、外部ソートでは64kBに変更します。
- バックグラウンドで状態が変わらないように、コンテナは`autovacuum=off`で起動します。第11章の複製テーブルには明示的にVACUUMを実行します。
- SQLは下表の順序で実行します。キャッシュは測定間で空にしていません。
- `ANALYZE`の標本は毎回変わるため、推定件数は再実行すると異なることがあります。

## ファイルと確認結果

| ファイル | 対応する章と確認すること |
| --- | --- |
| `setup.sql` / `setup.log` | 空のDBに本と読書記録を作成。実験用リポジトリの`sql/01/00-setup.sql`と同じ生成式を使用 |
| `conditions.sql` / `conditions.log` | バージョン、設定、期間、件数、日時の一意性 |
| `ch05.sql` / `ch05.log` | 9月20日分71,428件のBitmap Scan、exact=10,811ページ。最後に日時Indexを削除 |
| `ch06.sql` / `ch06.log` | 50万件のquicksortとexternal merge。内容・重複・順序の一致 |
| `trace.sql` / `trace.log` | 外部ソートの428→72→12→2の合流 |
| `ch07.sql` / `ch07.log` | LIMITなしとLIMIT 20を比較。Indexを作ったあとの20件も照合 |
| `ch08.sql` / `ch08.log` | 3種類のJOINで50万件の内容・重複が一致 |
| `ch09.sql` / `ch09.log` | 2種類の集計で736,097グループの件数が一致。推定は77,358 |
| `ch10.sql` / `ch10.log` | 統計を取り直したときの推定は76,011。実際は736,097グループ |
| `ch11.sql` / `ch11.log` | Index Only ScanのHeap Fetchesは0→2→0。途中で同じ検索を繰り返したときは1 |
| `check-results.py` / `check-results.log` | ソート、上位20件、JOIN、集計、本ごとの件数を照合 |
| `check-manuscript.py` / `check-manuscript.log` | 原稿の出力・数値・参照先をログと照合 |
| `initial-check.sql` / `initial-check.log` / `initial-check-negative.log` | 初期件数チェックが正常データを受け入れ、1件だけ週を変えると拒否。後者のERRORは意図した検出結果で、変更はROLLBACK済み |

## 実行方法

DockerとPython 3がある環境で、このフォルダへ移動して実行します。専用コンテナで測定し、終了時に削除します。出力先には、まだ存在しないディレクトリを指定してください。

```sh
python3 run.py /tmp/reading-records-results
```

SQLと採取済みログは上書きせず、指定したディレクトリに実行結果を保存します。`rerun-check-results.log`でも、空の別コンテナから実行した結果の一致を確認できます。

SQLを個別に実行する場合は、空のDBに`setup.sql`を1回だけ実行し、その後は表の順序で進めます。`ch11.sql`の`heap_state`は、更新前の`(4428,6)`と更新後の`(10810,151)`を調べます。データを変えて試す場合は、最初のctidと照らし合わせてください。

原稿との照合は、原稿のフォルダを引数で指定して実行します。

```sh
python3 check-manuscript.py /path/to/zenn/books/postgresql-explain-algorithms
```

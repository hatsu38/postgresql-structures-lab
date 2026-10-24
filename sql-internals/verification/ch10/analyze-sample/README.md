# 第10章：ANALYZE が統計に使うレコードの件数（標本）

第10章の補足「第9章のグループ数の見積もりがずれた理由」で書く「`ANALYZE` が統計に使うのは、200万件から無作為に選んだ30,000件」の根拠にした。以前の本文は「`ANALYZE` が200万件すべてを読んでいない」と書いていたが、この表では `ANALYZE` が全10,811ページを読んでいたので、直した。

## 環境

- 手元の Mac に作った一時クラスタ（PostgreSQL 18.3、Homebrew、aarch64-apple-darwin25.2.0）。測定後に停止して、データを捨てた。
- `autovacuum=off`、`max_parallel_workers_per_gather=0`、`jit=off`、block_size=8192、`default_statistics_target=100`（既定値のまま）。
- データベース名は `reading_map`。読書記録 `reading_records` だけを作る（`books` は使わない）。データの作り方は `ch10/stats/setup.sql` と同じ。
- 他のディレクトリの測定は PostgreSQL 18.6（Docker）なので、環境が違う。`ANALYZE` は標本を無作為に選ぶので、`n_distinct` は実行のたびに変わる（`stats` の 77,812 も、ここの3回の値も、別の標本から出た値）。

## 再現手順

```sh
psql -X -a -U postgres -d reading_map < observe.sql > observe.log 2>&1
```

`observe.sql` は、最後に800万件の `big_records`（約340MB）を作るので、手元で流すときは空き容量に注意する。

## 確認した結果（observe.log）

| 観察 | 値 |
| --- | --- |
| `reading_records` のレコード数・ファイルのページ数 | 2,000,000件・10,811ページ |
| `ANALYZE` する前の `relpages` / `reltuples` | 0 / -1 |
| `ANALYZE VERBOSE`（統計目標100）が読んだページ数 | `scanned 10811 of 10811 pages`（全ページ） |
| 標本のレコード数（統計目標100） | `30000 rows in sample`（3回とも同じ） |
| 3回の `ANALYZE` のあとの `book_id` の `n_distinct` | 76,634・77,882・76,296 |
| `book_id` の実際の種類数 | 736,097 |
| 統計目標を1000にしたときの標本のレコード数 | `300000 rows in sample`（読んだページ数は同じ全ページ） |
| 統計目標1000のときの `n_distinct` | -0.145453（負の値は、種類数 ÷ 件数の符号を逆にした値。2,000,000 × 0.145453 ≒ 29万種類） |
| `big_records`（800万件、2列）のレコード数・ファイルのページ数 | 8,000,000件・43,264ページ |
| `big_records` で `ANALYZE VERBOSE`（統計目標100）が読んだページ数・標本 | `scanned 30000 of 43264 pages`・`30000 rows in sample` |

読み取れること：

- `reading_records` は10,811ページしかなく、`ANALYZE` が1回に選ぶページ数の上限（30,000ページ）より少ないので、全ページを読んだ。それでも統計に使うレコードは、その中から無作為に取り出した30,000件だけだった。
- 標本のレコード数は、統計目標の300倍になった（100 → 30,000、1000 → 300,000）。
- ページ数が30,000を超える `big_records` では、読むページも30,000ページに頭打ちになり、レコードを数える標本も30,000件のままだった。
- 統計目標を1000に上げても、`n_distinct` は約29万種類までで、実際の736,097種類には届かなかった。

## ソースコード（REL_18_STABLE、読んだだけで、改造して動かしてはいない）

`src/backend/commands/analyze.c` の `std_typanalyze()` が、列ごとに `stats->minrows = 300 * stats->attstattarget;` と決める（コメントは、ヒストグラムの誤差から出した「300 × 区間数」の根拠を書いている）。`do_analyze_rel()` は、分析する列の `minrows` の最大値を、標本に取るレコード数 `targrows` にする。`acquire_sample_rows()` のコメントは、「無作為に選んだ `targrows` 個までのブロック（そんなに数がなければ全ブロック）を読み、Vitter のアルゴリズムで `targrows` 個までのレコードを標本にする」と書いている。上の結果と合っている。

## 確認できていないこと

- PostgreSQL 18.6 では測っていない。ソースは REL_18_STABLE のものを読んだ。
- 統計目標が列ごとに違うとき（`ALTER TABLE ... SET STATISTICS`）、標本の件数が最大の目標で決まることは、測っていない。公式ドキュメントの `ANALYZE` のページに「分析する列のうち、最大の統計目標が、標本に取るレコード数を決める」とあるのを読んだだけである。
- テーブルが継承やパーティションを持つ場合は測っていない。

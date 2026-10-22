# 検証ログ

『EXPLAINを読みながら学ぶPostgreSQLとアルゴリズム』に載せた実行結果を、測定したときのSQLと全出力です。本の脚注にある「実験用リポジトリの `sql-internals/verification/ch06/`」は、この下の `ch06/` を指します。

## 読み方

- ファイルは、測定したときのまま置いています。編集していません。
- ディレクトリは、本の章ごとにまとめています。各ディレクトリの README やスクリプトに出てくる章番号（「第5章」など）は、測定した時点の旧番号のことがあります。本の章との対応は、次の表を見てください。「測定時のディレクトリ名」は、README の中で別のディレクトリを指すときの名前です。
- README の実行例にある `_drafts/postgresql-sql-internals/verification/…` や `books/…` のパスは、測定したときの原稿のリポジトリ（非公開）のものです。ここでは、同じディレクトリの SQL を使ってください。
- `check-results.py` と `check-manuscript.py` は、原稿に書いた数字をログと照らし合わせるスクリプトです。原稿のリポジトリを読むので、ここでは動きません。照合した結果は `check-*.log` にあります。
- コンテナ名の `claude-pg-…` は、測定用に一時的に作った PostgreSQL のコンテナの名前です。

## 測定の環境

測定は、Docker の専用コンテナで、PostgreSQL 18.6 を使って行いました。イメージのダイジェストと、並列実行・JIT・`work_mem` などの設定は、各ディレクトリの README に書いてあります（`syntax-tree` だけは、PostgreSQL 18.6 のパーサを組み込んだ pglast 8.5 で構文解析した結果です）。

実行時間やバッファアクセス数は、環境や直前の処理によって変わります。ミリ秒の一致ではなく、処理の方法とレコード数を比べてください。

## 本の章との対応

| 本の章 | ディレクトリ | 測定日 | 測定時のディレクトリ名 | 内容 |
| --- | --- | --- | --- | --- |
| 第1章 | [`ch01/stages-20261006`](ch01/stages-20261006) | 2026-10-06 | `ch01-20261006` | パーサ・リライタ・プランナ・エグゼキュータの各段階で止まるエラー、ビューの展開、計画と実行の時間（README はなく、`stages.sql` の先頭に説明がある） |
| 第1章 | [`ch01/syntax-tree`](ch01/syntax-tree) | | `ch01-syntax-tree` | 図1.2：冒頭のSQLを pglast 8.5 で構文解析した結果 |
| 第2章 | [`ch02/explain-20261003`](ch02/explain-20261003) | 2026-10-03 | `ch01-20261003` | 題名検索の結果、EXPLAIN、EXPLAIN ANALYZE |
| 第3章 | [`ch03/books-20261010`](ch03/books-20261010) | 2026-10-10 | `ch03-books-20261010` | `books` の `ctid` とページ数 |
| 第4章 | [`ch04/index-20261004`](ch04/index-20261004) | 2026-10-04 | `ch03-20261004` | 題名の Index を作る前後の同じ検索（Seq Scan と Index Scan）、Index の大きさ、番号の範囲検索 |
| 第5章 | [`ch05/books-buffer-20261012`](ch05/books-buffer-20261012) | 2026-10-12 | `ch05-books-buffer-20261012` | 共有バッファの再利用（`Buffers` の `hit`・`read`） |
| 第5章 | [`ch05/reading-records-20261004`](ch05/reading-records-20261004) | 2026-10-04 | `ch04-reading-records-20261004` | 読了日時で9月20日の記録を検索する（Bitmap Index Scan・Bitmap Heap Scan） |
| 第6章 | [`ch06/sort-20261004`](ch06/sort-20261004) | 2026-10-04 | `ch05-20261004` | ソート（`work_mem` を64MBと64kBにして、499,998件を並べる。外部ソートの `trace_sort`） |
| 第7章 | [`ch07/top-n-20261004`](ch07/top-n-20261004) | 2026-10-04 | `ch06-20261004` | 全件ソートと `LIMIT 20` の top-N heapsort |
| 第8章 | [`ch08/join-20261004`](ch08/join-20261004) | 2026-10-04 | `ch07-20261004` | JOIN（本100万冊・読書記録200万件。補足の表の値） |
| 第8章 | [`ch08/small-20261013`](ch08/small-20261013) | 2026-10-13 | `ch08-small-20261013` | 本3冊・読書記録4件の結合計画（Nested Loop・Hash Join・Merge Join） |
| 第9章 | [`ch09/aggregate-20261004`](ch09/aggregate-20261004) | 2026-10-04 | `ch08-20261004` | 集計（HashAggregate と GroupAggregate。Python でも本ごとの件数を数えて照合した） |
| 第9章 | [`ch09/small-20261015`](ch09/small-20261015) | 2026-10-15 | `ch09-small-20261015` | 読書記録5件の集計計画 |
| 第10章 | [`ch10/stats-20261004`](ch10/stats-20261004) | 2026-10-04 | `ch09-20261004` | 統計・推定件数・cost（読書記録200万件の集計の `n_distinct` など） |
| 第10章 | [`ch10/agg-cost-20261018`](ch10/agg-cost-20261018) | 2026-10-18 | `ch10-agg-cost-20261018` | 読書記録5件の集計で、HashAggregate と GroupAggregate の cost を比べる |
| 第10章 | [`ch10/cats-20261018`](ch10/cats-20261018) | 2026-10-18 | `ch10-cats-20261018` | 猫の血液型のテーブル `cats` の統計・cost・統計の更新 |
| 第11章 | [`ch11/mvcc-vacuum-20261004`](ch11/mvcc-vacuum-20261004) | 2026-10-04 | `ch10-20261004` | Visibility Map と Index Only Scan（同じディレクトリに、本では扱わない Repeatable Read との比較も入っている） |
| 第11章 | [`ch11/two-sessions-rc-20261019`](ch11/two-sessions-rc-20261019) | 2026-10-19 | `ch11-two-sessions-rc-20261019` | 2つの接続の実験（Read Committed）と、実行中の SELECT が元のレコードを残す実験 |
| 第11章 | [`ch11/xmin-xmax-20261020`](ch11/xmin-xmax-20261020) | 2026-10-20 | `ch11-xmin-xmax-20261020` | レコードに付いたトランザクションの番号（`xmin`・`xmax`） |
| 第11章 | [`ch11/cats-vacuum-20261019`](ch11/cats-vacuum-20261019) | 2026-10-19 | `ch11-cats-vacuum-20261019` | `cats` の UPDATE・VACUUM 前後のページ数 |
| 第11章 | [`ch11/cats-pages-20261022`](ch11/cats-pages-20261022) | 2026-10-22 | `ch11-cats-pages-20261022` | `cats` の UPDATE・VACUUM 前後のページの中身（空のページが18ページ残る）と、作り方によるページ数の違い（PostgreSQL 18.3、手元の一時クラスタ） |
| 第11章 | [`ch11/update-same-page-20261022`](ch11/update-same-page-20261022) | 2026-10-22 | `ch11-update-same-page-20261022` | 更新した新しいレコードが、同じページに置かれるか別のページに置かれるか（元のページの空きが28バイトなら別のページ、fillfactor 90で空きがあれば同じページ。PostgreSQL 18.3、手元の一時クラスタ） |

第12章（「おわりに」）は、実行結果を載せていないので、このディレクトリにはありません。

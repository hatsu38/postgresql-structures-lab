# 検証ログ

『EXPLAINを読みながら学ぶPostgreSQLとアルゴリズム』に載せたSQLと実行結果の全出力です。章と内容から、次の表で探せます。

読書記録200万件を使う実験は、[読書記録の実験](reading-records/README.md)にまとめています。環境の準備から結果の照合まで、DockerとPython 3で実行できます。

## 測定環境

PostgreSQLのバージョンと設定は各フォルダのREADMEまたはログで確認できます。実行時間やバッファアクセス数は、環境や直前の処理によって変わるため、処理の方法とレコード数を比べてください。

## 本の章との対応

| 本の章 | SQLと出力 | 内容 |
| --- | --- | --- |
| 第1章 | [SQL・ログ](ch01/stages-20261006) | パーサ・リライタ・プランナ・エグゼキュータの各段階で止まるエラー、ビューの展開、計画と実行の時間（README はなく、`stages.sql` の先頭に説明がある） |
| 第1章 | [SQL・ログ](ch01/syntax-tree) | 図1.2：冒頭のSQLを pglast 8.5 で構文解析した結果 |
| 第2章 | [SQL・ログ](ch02/explain-20261003) | 題名検索の結果、EXPLAIN、EXPLAIN ANALYZE |
| 第3章 | [SQL・ログ](ch03/books-20261010) | `books` の `ctid` とページ数 |
| 第4章 | [SQL・ログ](ch04/index-20261004) | 題名の Index を作る前後の同じ検索（Seq Scan と Index Scan）、Index の大きさ、番号の範囲検索 |
| 第5章 | [SQL・ログ](ch05/books-buffer-20261012) | 共有バッファの再利用（`Buffers` の `hit`・`read`） |
| 第5章 | [SQL・ログ](ch05/hit-consecutive-20261022) | Index Scan が同じページを続けて使うときと、間に別のページをはさんで戻るときの `hit` の数え方（PostgreSQL 18.3、手元の一時クラスタ） |
| 第5章 | [SQL](reading-records/ch05.sql)・[ログ](reading-records/ch05.log) | 9月20日の71,428件をBitmap Scanで検索 |
| 第6章 | [SQL](reading-records/ch06.sql)・[ログ](reading-records/ch06.log) | 50万件のソート。work_memを64MBと64kBで比較。trace.logに外部ソートの合流 |
| 第7章 | [SQL](reading-records/ch07.sql)・[ログ](reading-records/ch07.log) | 全件ソートとLIMIT 20のtop-N heapsort |
| 第8章 | [SQL](reading-records/ch08.sql)・[ログ](reading-records/ch08.log) | 本100万冊・読書記録200万件で3種類のJOINを比較 |
| 第8・9章 | [SQL](small-samples/observe.sql)・[ログ](small-samples/observe.log) | 星・海・森の通常テーブルを作成し、新しい接続でJOIN・集計を手動確認。計画を切り替えるSETなしでHash Joinが4件、HashAggregateが3件を返した |
| 第8〜10章 | [SQL](small-samples/compare.sql)・[ログ](small-samples/compare.log)・[説明](small-samples/README.md) | 同じ通常テーブルで3種類のJOINと2種類の集計を比較。SUM・AVG・NULLの扱いと集計のcostも確認 |
| 第9章 | [SQL](reading-records/ch09.sql)・[ログ](reading-records/ch09.log) | HashAggregateとGroupAggregateの結果を照合 |
| 第10章 | [SQL](reading-records/ch10.sql)・[ログ](reading-records/ch10.log) | 読書記録200万件の集計のn_distinctと推定件数 |
| 第10章 | [SQL](cats-sample/observe.sql)・[ログ](cats-sample/observe.log)・[説明](cats-sample/README.md) | 準備済みの猫1万匹で、A型・B型の検索とUPDATE・ANALYZE前後の統計を確認。検索方法を切り替えるSETなしで観察 |
| 第10章 | [SQL・ログ](ch10/cats-20261018) | 猫の血液型のテーブル `cats` の統計・cost・統計の更新 |
| 第10章 | [SQL・ログ](ch10/analyze-sample-20261022) | `ANALYZE` が統計に使うレコードの件数（読書記録200万件では全ページを読み、標本は30,000件。PostgreSQL 18.3、手元の一時クラスタ） |
| 第11章 | [SQL・ログ](ch11/two-sessions-rc-20261019) | 2つの接続の実験（Read Committed）と、実行中の SELECT が元のレコードを残す実験 |
| 第11章 | [SQL・ログ](ch11/xmin-xmax-20261020) | レコードに付いたトランザクションの番号（`xmin`・`xmax`） |
| 第11章 | [SQL・ログ](ch11/cats-vacuum-20261019) | `cats` の UPDATE・VACUUM 前後のページ数 |
| 第11章 | [SQL・ログ](ch11/cats-pages-20261022) | `cats` の UPDATE・VACUUM 前後のページの中身（空のページが18ページ残る）と、作り方によるページ数の違い（PostgreSQL 18.3、手元の一時クラスタ） |
| 第11章 | [SQL](reading-records/ch11.sql)・[ログ](reading-records/ch11.log) | 更新・VACUUM前後のレコード、Indexの項目、可視性マップ、Heap Fetches |
| 第11章 | [SQL・ログ](ch11/update-same-page-20261022) | 更新した新しいレコードが、同じページに置かれるか別のページに置かれるか（元のページの空きが28バイトなら別のページ、fillfactor 90で空きがあれば同じページ。PostgreSQL 18.3、手元の一時クラスタ） |

「おわりに」には実行結果を載せていません。

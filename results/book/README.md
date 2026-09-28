# 本に載せたSQLと実行結果

本の原稿に載せていたSQLと実行結果の全文です。紙面では本文が読む行だけを抜粋しているので、全体を見比べたいときはここを開いてください。

| 章 | ファイル | コード枠の数 |
| --- | --- | ---: |
| 序章：20冊のランキングが、なかなか出てこない | [00-prologue.md](00-prologue.md) | 4 |
| 準備：実験環境を作る | [00-setup.md](00-setup.md) | 14 |
| 第1章：EXPLAIN ANALYZEで、SQLの動きを観察する | [01-explain-basics.md](01-explain-basics.md) | 14 |
| 第2章：LIMIT 1なら、見つかったところで止まるのか | [02-linear-search.md](02-linear-search.md) | 14 |
| 第3章：B-treeは、どうやって探す場所を絞るのか | [03-btree-index.md](03-btree-index.md) | 22 |
| 第4章：テーブルのレコードは、どのページに保存されているのか | [04-pages-and-storage.md](04-pages-and-storage.md) | 18 |
| 第5章：同じページを、毎回ストレージから読むのか | [05-memory-and-buffers.md](05-memory-and-buffers.md) | 20 |
| 第6章：長い実行計画は、どこから読むのか | [06-process-and-execution.md](06-process-and-execution.md) | 13 |
| 第7章：50万件のSortは、work_memに収まるのか | [07-sort.md](07-sort.md) | 13 |
| 第8章：top-N heapsortは、上位20件をどう選ぶのか | [08-top-n-heap.md](08-top-n-heap.md) | 7 |
| 第9章：JOINと集計は、件数によって方法をどう変えるのか | [09-join.md](09-join.md) | 12 |
| 第10章：PostgreSQLは、なぜその計画を選んだのか | [10-planner-and-statistics.md](10-planner-and-statistics.md) | 12 |
| 第11章：MVCCでは、更新中のレコードは読み手にどう見えるのか | [11-mvcc-and-maintenance.md](11-mvcc-and-maintenance.md) | 17 |
| 第12章：ランキングを速くする3つの案を、実行計画で比べる | [12-ranking-revisited.md](12-ranking-revisited.md) | 17 |
| 付録：自分の遅いSQLを調べる | [98-appendix-slow-sql.md](98-appendix-slow-sql.md) | 20 |

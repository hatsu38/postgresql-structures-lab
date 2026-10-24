# 星・海・森の小さな例

第8〜10章で使う本3冊と読書記録を、準備済みの通常テーブルで確認します。

| テーブル | 内容 |
| --- | --- |
| `public.books_sample` | 本3冊：星・海・森 |
| `public.join_records_sample` | JOIN用の記録4件：2・1・2・4 |
| `public.aggregate_records_sample` | 集計用の記録5件：2・1・2・4・2 |

## 設定を変えずに観察する

[observe.sql](observe.sql)はJOINと集計を実行し、`EXPLAIN (ANALYZE, BUFFERS)`で計画を確認します。[observe.log](observe.log)は、サンプルの準備から、新しい接続でSELECT・EXPLAINを実行した手元の全出力です。結合・集計方法の設定を変えずに、Hash Joinが4件、HashAggregateが3件を返しました。

## 方法を指定して比較する

[compare.sql](compare.sql)と[compare.log](compare.log)には、本文で比べる各方式の計画を収録しています。PostgreSQL 18.6の専用コンテナで、`sql/samples.sql`を実行してから確認しました。

- 第8章：Nested Loop、Indexを使うNested Loop、Hash Join、Merge Join
- 第9章：HashAggregate、GroupAggregate、SUM・AVGとNULLの扱い
- 第10章：集計用テーブルの統計と、2種類の集計のcost

通常の設定で選ばれる計画を確認したあと、別の方法も観察できるように、比較する箇所だけ`BEGIN`から`ROLLBACK`までの中で`SET LOCAL`を使います。テーブルのデータは書き換えません。件数と繰り返し回数を見る計画では、costや時間などの表示を省いています。

## 再実行する

実験用リポジトリ（postgresql-structures-lab）のルートで実行します。共通初期化でデータを用意してあれば、最初のコマンドは省けます。入れ直す場合は、小さな例の3テーブルだけを初期化します。

```sh
docker compose exec -T db psql -X -1 -v ON_ERROR_STOP=1 -U postgres -d reading_map -f /lab/sql/samples.sql
docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -U postgres -d reading_map < sql-internals/verification/small-samples/observe.sql
docker compose exec -T db psql -X -a -v ON_ERROR_STOP=1 -U postgres -d reading_map < sql-internals/verification/small-samples/compare.sql
```

計画と時間は環境や設定で変わるため、ノードの名前・件数・繰り返し回数を比べてください。比較ログの先頭にはPostgreSQLのバージョンと、メモリ・costの設定も残しています。

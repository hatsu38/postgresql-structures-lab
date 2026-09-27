# 序章のランキング計測（2026-09-21）

本の序章「20冊を返すまで、約4.6秒」と、その節の「この数値を測った条件」の出典です。本の主実験（通常テーブル、本100万冊・読了記録200万件）とは別の条件で測りました。

## 計測結果

2026-09-21、Apple M1 Pro / 32GiB RAM / PostgreSQL 18.3（Homebrew）。`work_mem=64MB`、並列実行とJITは無効。読了日時は2026-08-24からの4週間に分布し、9月14日以上・21日未満を対象週にしました。読了記録に人気の偏りはない合成データです。

| 条件 | 3回のpsql経過時間（ms） | 中央値（ms） |
| --- | --- | --- |
| 本1,000冊・記録2万件 | 2.466 / 2.140 / 2.017 | 2.140 |
| 本100万冊・記録2,000万件 | 4630.241 / 4553.647 / 4531.875 | 4553.647 |

生ログは `weekly-ranking-small-pg18.3-20260921.txt` と `weekly-ranking-large-pg18.3-20260921.txt` です。

大きい方の対象週は4,999,999件でした。実行計画には読了記録のSeq Scan、Hash Join、HashAggregate、top-N heapsortが現れました。別に測ったEXPLAINのExecution Timeは4611.826msです。集計結果は100万グループで、最後に20行を返します。

## 再実行

SQL は [`sql/00/prologue-weekly-ranking.sql`](../../sql/00/prologue-weekly-ranking.sql) です。一時テーブルの中で完結し、最後にROLLBACKするので、本の実験用のテーブルは変更しません。文ごとのタイムアウトは90秒です。

```sh
docker compose exec -T db psql -X -U postgres -d postgres -f /lab/sql/00/prologue-weekly-ranking.sql
docker compose exec -T db psql -X -U postgres -d postgres -v book_count=1000 -v record_count=20000 -f /lab/sql/00/prologue-weekly-ranking.sql
```

1行目が本100万冊・記録2,000万件、2行目が本1,000冊・記録2万件です。大きい方は一時的に約902MBのデータ領域を使います。計測したときとは PostgreSQL のバージョンと動かす環境が違うので、時間は同じになりません。

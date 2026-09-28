# 序章：20冊のランキングが、なかなか出てこない

本の原稿（2026-09-28 時点）に載せていたSQLと実行結果を、章の中の順に抜き出したものです。紙面では、本文が読む行だけを抜粋しています。自分の結果と見比べるときに使ってください。時間と`Buffers`の数は、環境や直前の処理で変わります。

### ランキングのSQLが求めている結果

SQL:

```sql
SELECT b.id, b.title, count(*) AS read_count
FROM books AS b
JOIN reading_records AS r ON r.book_id = b.id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21'
GROUP BY b.id, b.title
ORDER BY read_count DESC, b.id ASC
LIMIT 20;
```

#### このSQLを試すには

ターミナル:

```sh
docker compose exec db psql -X -U postgres -d reading_map
```

SQL:

```sql
SELECT b.id, b.title, count(*) AS read_count
FROM books AS b
JOIN reading_records AS r ON r.book_id = b.id
WHERE r.finished_at >= timestamp '2026-09-14'
  AND r.finished_at < timestamp '2026-09-21'
GROUP BY b.id, b.title
ORDER BY read_count DESC, b.id ASC
LIMIT 20;
```

実行結果:

```text
   id   |       title       | read_count 
--------+-------------------+------------
 386414 | 実験用の本 386414 |       5009
 772827 | 実験用の本 772827 |       3267
 159240 | 実験用の本 159240 |       2485
 545653 | 実験用の本 545653 |       2033
 932066 | 実験用の本 932066 |       1724
 318479 | 実験用の本 318479 |       1504
 704892 | 実験用の本 704892 |       1344
  91305 | 実験用の本 91305  |       1213
 477718 | 実験用の本 477718 |       1118
 864131 | 実験用の本 864131 |       1031
 250544 | 実験用の本 250544 |        957
 636957 | 実験用の本 636957 |        896
  23370 | 実験用の本 23370  |        838
 409783 | 実験用の本 409783 |        795
 796196 | 実験用の本 796196 |        747
 182609 | 実験用の本 182609 |        711
 569022 | 実験用の本 569022 |        679
 955435 | 実験用の本 955435 |        652
 341848 | 実験用の本 341848 |        624
 728261 | 実験用の本 728261 |        599
(20 rows)
```

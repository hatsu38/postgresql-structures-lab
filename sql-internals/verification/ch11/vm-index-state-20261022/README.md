# 第11章：更新後・再VACUUM後の、元のレコードとIndexの項目の状態

2026-10-22に実施。第11章の表11.1と図11.7（Index Only Scan の `Heap Fetches` が 0→2→0 に変わる実験）の、「再びVACUUM」の場面で、元のレコードと Index の項目に何が起きているかを確かめた。`mvcc-vacuum-20261004` の `visibility.sql` と同じ手順に、状態を読む問い合わせを足している。状態は、ページの中身を読む関数（`pageinspect` の `heap_page_items`・`bt_page_items`）と、可視性マップ（`pg_visibility`）で読んだ。更新の直後に `mvcc_reading_records` を全件読むと、読んだ時点で状態が変わるので、検索の前の状態は、検索を使わずに読んでいる。

## 環境

- 手元の Mac に作った一時クラスタ（PostgreSQL 18.3、Homebrew、aarch64-apple-darwin25.2.0）。測定後に停止して、データを捨てた。
- `autovacuum=off`、`max_parallel_workers_per_gather=0`、`jit=off`、block_size=8192。観察用のテーブル `mvcc_reading_records` は `autovacuum_enabled = false` で作った。
- データは、本100万冊・読書記録200万件の初期データ（`sql/01/00-setup.sql`）。データベース名は `reading_map`。`pageinspect` と `pg_visibility` の拡張を使うので、スーパーユーザーで実行する。
- 他の記録（`mvcc-vacuum-20261004`）は PostgreSQL 18.6（Docker）なので、環境が違う。同じ手順の `Heap Fetches`（0→2→0）と、ページ4428・10810の可視性マップの印（`t・t` → `f・f` → `f・t`）は、その記録と一致した。

## 再現手順

```sh
psql -X -a -U postgres -d reading_map < observe.sql > observe.log 2>&1
```

## 確認した結果（observe.log）

本42の読書記録1件を、「元のレコード（ページ4428の6番）」と「新しいレコード（ページ10810の151番）」と呼ぶ。`lp_flags` は、1が「レコードがある」、3が「片付けられた（領域は空いた）」を表す。

| 時点 | 元のレコード | 新しいレコード | Indexの項目に「不要」の印（元／新） | `Heap Fetches` |
| --- | --- | --- | --- | ---: |
| 最初のVACUUM後 | `lp_flags=1`、ページに all-visible の印あり | なし | なし／— | 0 |
| 日時を更新してCOMMITした直後（検索の前） | `lp_flags=1`、`t_xmax=767`、ページの印なし | `lp_flags=1`、ページの印なし | なし／なし | — |
| 1回目の Index Only Scan のあと | **`lp_flags=3`（片付けられていた）**、ページの印なし | `lp_flags=1`、ページの印なし | **あり**／なし | 2 |
| VACUUMの前の2回目の検索 | 同じ | 同じ | 同じ | 1 |
| 再びVACUUM後 | `lp_flags=3` のまま、ページの印は **`false`** | `lp_flags=1`、ページの印が **`true`** | あり（項目は残ったまま）／なし | 0 |

再びVACUUMしたときの `VACUUM (VERBOSE)` の出力：

```
index scans: 0
tuples: 0 removed, 2000000 remain, 0 are dead but not yet removable
visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
index scan bypassed: 1 pages from table (0.01% of total) have 1 dead item identifiers
```

- 元のレコードは、VACUUM より前に、1回目の Index Only Scan がテーブルのページを確認したときに、すでに片付けられていた（`lp_flags` が1から3になった）。そのため、VACUUM は、レコードを1件も片付けていない（`0 removed`）。
- Index の項目は、VACUUM で消えなかった。元のレコードを指す項目は、1回目の検索のあとに「不要」の印が付き、VACUUM のあとも残っている。印が付いた項目は、次の検索で読み飛ばされるので、元のレコードのために、テーブルを確認する必要がなくなる。
- VACUUM が all-visible の印を付けたのは、新しいレコードのページだけ（`1 pages set all-visible`）。元のレコードを置いていたページは、片付けた項目の番号が残るので、印が付かない。

## 根拠（ソースと公式）

- VACUUM が Index の掃除を省く条件：`src/backend/access/heap/vacuumlazy.c`（REL_18_STABLE）の `lazy_vacuum()`。`BYPASS_THRESHOLD_PAGES 0.02`（テーブルのページ数の2%）より、片付けた項目のあるページが少ないとき、Index の掃除とヒープの掃除を省く。コメントに、「it's a proxy for the number of heap pages whose visibility map bits cannot be set on account of bypassing index and heap vacuuming」とある（Index とヒープの掃除を省くと、印を付けられないページが出る）。
- 「不要」の印が付いた Index の項目を読み飛ばす処理：`src/backend/access/nbtree/nbtsearch.c`（REL_18_STABLE）の `_bt_readpage()`。`if (scan->ignore_killed_tuples && ItemIdIsDead(iid)) { ... continue; }`。
- 公式の説明：https://www.postgresql.org/docs/18/sql-vacuum.html の `INDEX_CLEANUP`。「Normally, VACUUM will skip index vacuuming when there are very few dead tuples in the table.」

## 確認できていないこと

- ページの枝刈りが起きるかどうかは、ページの空き具合で変わる。この `CREATE TABLE AS` のテーブルはページが詰まっているので起きたが、空きの多いテーブルでは、元のレコードが片付けられる時期が変わる可能性がある。
- PostgreSQL 17 以前での挙動は、測っていない。

# 第11章：更新した新しいレコードが、元のレコードと同じページに置かれるか、別のページに置かれるか

2026-10-22に実施。第11章の表11.1と図11.7（Index Only Scan の `Heap Fetches` が 0→2→0 に変わる実験）の更新で、新しいレコードが、元のレコードとは別のページに置かれた理由を確かめた。あわせて、同じ SQL で、ページに空きを残しておくと、新しいレコードが同じページに置かれることを確かめた。本文の「更新すると、新しいレコードは別のページに置かれ」が、この章の冒頭の「新しいレコードを同じページの別の場所に作ります」と食い違っていたので、どちらになるかは、元のレコードのページの空きで決まることを確認するために行った。

`vm-index-state-20261022` と同じく、更新の前後のページの状態は、検索を使わずに、ページの中身を読む関数（`pageinspect` の `page_header`・`heap_page_items`）と可視性マップ（`pg_visibility`）で読んでいる。更新の直後にこのテーブルを検索すると、読んだ時点でページの中身が変わる（ページの枝刈り）ためである。更新したレコードの新しい場所は、`UPDATE ... RETURNING ctid` で受け取った。

## 環境

- 手元の Mac に作った一時クラスタ（PostgreSQL 18.3、Homebrew、aarch64-apple-darwin25.2.0）。測定後に停止して、データを捨てた。
- `autovacuum=off`、`max_parallel_workers_per_gather=0`、`jit=off`、block_size=8192。観察用のテーブルは `autovacuum_enabled = false` で作った。
- データは、本100万冊・読書記録200万件の初期データ（`sql/01/00-setup.sql`）。データベース名は `reading_map`。`pageinspect` と `pg_visibility` の拡張を使うので、スーパーユーザーで実行する。
- 本42の読書記録1件の場所（`(4428,6)`）と、更新で置かれた新しい場所（`(10810,151)`）は、`vm-index-state-20261022` と一致した。

## 再現手順

```sh
psql -X -a -U postgres -d reading_map < observe.sql > observe.log 2>&1
```

## 確認した結果（observe.log）

本42の読書記録1件を、元のレコード（ページ4428の6番）と呼ぶ。`page_header` の `lower` は項目の番号の表の終わり、`upper` はレコードを置く領域の始まりで、`upper - lower` がそのページの空きのバイト数になる。

### 1. 表11.1と同じ作り方（`CREATE TABLE ... AS`、fillfactor は既定の100）

| 観察 | 値 |
| --- | --- |
| 更新の前、元のレコードのページ（4428）の空き | 28バイト（`lower=764`、`upper=792`） |
| 更新の前、ページ10810の空き | 1,568バイト（`lower=624`、`upper=2192`） |
| 新しいレコードの長さ（`lp_len`） | 40バイト |
| 更新で、新しいレコードが置かれた場所 | `(10810,151)`（元のレコードのページ4428ではない） |
| 元のレコードの項目（更新の後） | `lp_flags=1`、`lp_len=40`、`t_xmax=807` |
| 可視性マップの印：更新の前（ページ4428・10810） | どちらも `true` |
| 可視性マップの印：更新の後（ページ4428・10810） | どちらも `false` |

元のレコードのページの空きは28バイトで、新しいレコードの長さ40バイトより小さい。そのため、新しいレコードは同じページに置けず、別のページに置かれた。可視性マップの印は、元のレコードのページと、新しいレコードが置かれたページの、両方で消えた。

### 2. 同じ SQL で、fillfactor を90にした

| 観察 | 値 |
| --- | --- |
| 本42の読書記録1件の場所（更新の前） | `(4905,51)` |
| 更新の前、そのページの空き | 820バイト |
| 更新で、新しいレコードが置かれた場所 | `(4905,168)`（同じページ4905） |
| 可視性マップの印：ページ4905の、更新の前・後 | `true`・`false` |

表11.1と同じ更新（Index に含む日時を変えるので、HOT 更新ではない）でも、ページに空きがあれば、新しいレコードは同じページに置かれた。印は、同じ1ページで消えた。

## 根拠（ソースと公式）

- `src/backend/access/heap/heapam.c`（REL_18_STABLE）の `heap_update()`。ページの空きを `pagefree = PageGetHeapFreeSpace(page);` で求め、`if (need_toast || newtupsize > pagefree)` のときだけ `RelationGetBufferForTuple()` で別のページを探す。そうでなければ、コメント「No TOAST work needed, and it'll fit on same page」のとおり、`newbuf = buffer;` で元のレコードと同じページに置く。
- 公式の説明：https://www.postgresql.org/docs/18/sql-createtable.html の `fillfactor`。「This gives UPDATE a chance to place the updated copy of a row on the same page as the original, which is more efficient than placing it on a different page」。

## 確認できていないこと

- 新しいレコードが、ページ10810に置かれた理由（空きのあるページを、どの順で選んだか）は調べていない。
- `PageGetHeapFreeSpace()` が、新しい項目の番号の分として引くバイト数は、ソースで確かめていない。ここでは、空きの28バイトが、レコードの長さ40バイトより小さいことだけを根拠にした。
- `CREATE TABLE ... AS` で作ったテーブルのファイルのページ数は、作るたびに変わった（この記録では10,855ページ）。本42の読書記録1件の場所と、新しい場所は、変わらなかった。
- PostgreSQL 17 以前での挙動は、測っていない。

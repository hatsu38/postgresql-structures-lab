# 第5章：同じページを続けて使うときの `hit` の数え方

2026-10-22に実施。第5章の表5.1と、その次の段落「同じページを繰り返し使った分も、`hit`に含まれます」について、Index Scan が同じページにあるレコードを続けて取り出すときと、間に別のページをはさんで同じページへ戻るときで、`Buffers` の `hit` がどう数えられるかを確かめた。本の測定記録（`books-buffer-20261012`）は、題名で1件を探す Index Scan だけだったので、複数のレコードを取り出す場合は、この記録で初めて測った。

## 環境

- 手元の Mac に作った一時クラスタ（PostgreSQL 18.3、Homebrew、aarch64-apple-darwin25.2.0）。測定後に停止して、データを捨てた。
- `shared_buffers=128MB`、`block_size=8192`、`work_mem=4MB`。`autovacuum=off`、`max_parallel_workers_per_gather=0`、`jit=off`。
- データは、本100万冊・読書記録200万件の初期データ（`ch05/books-buffer-20261012/setup.sql` と同じ内容。`diff` で同一を確認）。データベース名は `reading_map`。
- 他の記録は PostgreSQL 18.6（Docker）なので、環境が違う。番号で1件を探す A の `hit=4` は、`books-buffer-20261012` の、題名で1件を探す Index Scan の2回目（`hit=4`）と同じ値になった。

## 再現手順

初期データを入れた `reading_map` に、スーパーユーザーで次を実行する（`pageinspect` の拡張を作る）。`observe.sql` は、題名の Index（`books_title_idx`）も作る。

```sh
psql -X -a -U postgres -d reading_map < observe.sql > observe.log 2>&1
```

## 確認した結果（observe.log）

`ctid` は（ページ番号, ページ内番号）。番号1〜136の本はページ0、137番の本はページ1にある。題名の順に並べた「実験用の本 100」「実験用の本 1000」「実験用の本 101」の `ctid` は、(0,100)、(7,48)、(0,101)で、取り出す順にページ0、ページ7、ページ0と動く。`bt_metap` の `level` は、`books_pkey` も `books_title_idx` も2なので、Index は、根から葉まで3ページをたどる。

各SQLを2回ずつ実行した。表の `Buffers` は2回目の値で、すべて `shared hit` だけだった（`read` なし）。

| 場合 | 取り出した件数 | テーブルのページの順 | `Buffers`（2回目） | 内訳：Indexのページ＋テーブルのページ |
| --- | ---: | --- | --- | --- |
| A：番号1の1件 | 1 | 0 | `hit=4` | 3＋1 |
| B：番号1〜100 | 100 | 0（100件とも） | `hit=4` | 3＋1 |
| C：番号1〜272 | 272 | 0（136件）、1（136件） | `hit=5` | 3＋2 |
| D：題名2つ（100、101） | 2 | 0、0 | `hit=7`（`Index Searches: 2`） | 6＋1 |
| E：題名3つ（100、1000、101） | 3 | 0、7、0 | `hit=9`（`Index Searches: 2`） | 6＋3 |

- 内訳は、`pg_stat_get_xact_blocks_fetched()` で、テーブルとIndexに数えたページ数（`hit` と `read` の合計）を、実行の前後で引いて求めた。プランナがIndexやテーブルを読む分を除くため、計画を作り直さない設定（`plan_cache_mode = force_generic_plan`）で、同じSQLを2回実行し、2回目の前後を引いている。この合計（A：4、B：4、C：5、D：7、E：9）は、`EXPLAIN` の `hit` と一致した。
- B：100件を取り出しても、ページ0は1回しか数えていない。`hit=4` は、1件だけ取り出した A と同じ。
- C：2ページにまたがる272件で、テーブルのページは2回。
- D：ページ0の2件を続けて取り出すとき、ページ0は1回だけ。Index は、2回探索した（`Index Searches: 2`）ので、3ページ×2回の6ページ。
- E：ページ0、ページ7、ページ0の順に取り出すと、テーブルのページは3回。ページ0へ戻った分も数えている。
- A の1回目は `hit=7` だった。そのセッションで最初に実行したSQLで、原因は調べていない。B〜E は、1回目と2回目が同じ。
- F：Seq Scan（`SELECT count(*) FROM books`）。`books` は7,353ページ、100万件。1ページに136件入っているが、`hit` と `read` の合計は、1回目が 4,841＋2,512＝7,353、2回目が 4,935＋2,418＝7,353で、ページ数と同じ。

## 根拠（ソースと公式）

`REL_18_STABLE`（2026-10-22に取得）で確かめた。次の箇所は `REL_18_6` でも同じ（`heapam_handler.c` は全体が同一。`bufmgr.c` は、7159行目の1か所だけが違い、下の2つの関数は同じ行にある）。測定した PostgreSQL 18.3（`REL_18_3`）は、`heapam_handler.c` が同一で、`bufmgr.c` の行番号だけが違う（`ReleaseAndReadBuffer()` は3008〜3041行目、`shared_blks_hit++` は1157行目）。`ReleaseAndReadBuffer()` の中身は同じで、`PinBufferForBlock()` は、先頭の `pg_attribute_always_inline` と `pg_always_inline` の違いだけ。

- Index Scan がテーブルのページを取りに行く処理：`src/backend/access/heap/heapam_handler.c` の `heapam_index_fetch_tuple()`（133〜135行目）。
  ```c
  hscan->xs_cbuf = ReleaseAndReadBuffer(hscan->xs_cbuf,
                                        hscan->xs_base.rel,
                                        ItemPointerGetBlockNumber(tid));
  ```
- `src/backend/storage/buffer/bufmgr.c` の `ReleaseAndReadBuffer()`（3031〜3064行目）。持っているバッファが、目的のブロックと同じなら、そのまま返す。違うときだけ、持っているバッファを放して、`ReadBuffer()` で取り直す。
  ```c
   * ... However, if the passed buffer is valid and
   * already contains the desired block, we just return it as-is; and that
   * does save considerable work compared to a full release and reacquire.
  ...
  			if (bufHdr->tag.blockNum == blockNum &&
  				BufTagMatchesRelFileLocator(&bufHdr->tag, &relation->rd_locator) &&
  				BufTagGetForkNum(&bufHdr->tag) == forkNum)
  				return buffer;
  			UnpinBuffer(bufHdr);
  ...
  	return ReadBuffer(relation, blockNum);
  ```
- `shared_blks_hit`（`EXPLAIN` の `Buffers` の `shared hit`）を増やす場所：`bufmgr.c` の `PinBufferForBlock()`（1100行目から。1145〜1148行目）。ブロックが共有バッファで見つかったときに数える。この関数は、`ReadBuffer()` の側から呼ばれるので、`ReleaseAndReadBuffer()` が早く返す場合は呼ばれず、数えない。
  ```c
  		bufHdr = BufferAlloc(smgr, persistence, forkNum, blockNum,
  							 strategy, foundPtr, io_context);
  		if (*foundPtr)
  			pgBufferUsage.shared_blks_hit++;
  ```
- 公式：https://www.postgresql.org/docs/18/sql-explain.html の `BUFFERS`。「A hit means that a read was avoided because the block was found already in cache when needed.」。同じページを続けて使ったときの数え方は、書かれていない。

## 確認できていないこと

- Seq Scan と Bitmap Heap Scan が、同じページのレコードを続けて取り出すときの `hit` の数え方は、ソースを追っていない。Seq Scan は、ページ数の分しか数えないこと（F）だけ測った。
- 題名3つの `IN` で、Index を2回探索する（`Index Searches: 2`）理由は調べていない。内訳は測定で求めたもので、ソースでは追っていない。
- A の1回目が `hit=7` になる理由は調べていない。
- 並列実行を有効にしたとき、PostgreSQL 17 以前、PostgreSQL 18.6 での値は測っていない。

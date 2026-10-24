# 第11章：Read Committed だけの二接続実験と、実行中の SELECT が古い版を残す実験

二つのpsql接続A（読む役）とB（題名を変える役）で、本42「星の本」を読み書きした。分離レベルは既定のRead Committedのみで、Aは一度もBEGINしていない（autocommit）。主データ（books等）は使わず、専用の小さなテーブル`mvcc_books`だけを使った。

## 環境

- 専用一時コンテナ：`claude-pg-ch11-rc`。ポート公開なし、既存ボリュームの接続なし。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`
- PostgreSQL 18.6（Debian 18.6-1.pgdg13+2）、aarch64。
- DB名はreading_map、block_size=8192、default_transaction_isolation=read committed。
- `mvcc_books`だけautovacuum_enabled=false（autovacuumが勝手に片付けないようにするため）。
- 各操作の出力が完了してから次へ進める。ただし第2部のAの`pg_sleep(30)`だけは、完了を待たずにBを動かす。

## 保存ファイルと再現手順

1. two-sessions.py：二つのpsqlプロセスへSQLを送り、操作順と結果を記録する。`Session.start(sql)`は送って待たずに戻り、`finish()`が出力を終了マーカーまで読む。見える題名・ctid・VACUUMの出力をassertで確認する。
2. two-sessions.log：two-sessions.pyの出力。

```sh
docker run --detach --rm --name claude-pg-ch11-rc \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec claude-pg-ch11-rc pg_isready -U postgres -d reading_map
python3 two-sessions.py > two-sessions.log 2>&1
docker stop claude-pg-ch11-rc
```

ほかの長いトランザクションが動いていると、VACUUMの結果が変わる。実行中は同じDBに別の接続をつながない。第2部の待ち時間は`pg_sleep(30)`と、Bを動かす前の2秒。

## 第1部：確定前後の見え方とVACUUM

| 時点 | 接続 | 見えた題名 | ctid |
| --- | --- | --- | --- |
| INSERT直後 | A | 星の本 | (0,1) |
| BのUPDATE後、COMMIT前 | B（自分の更新） | 新しい星の本 | (0,2) |
| BのUPDATE後、COMMIT前 | A | 星の本 | (0,1) |
| BのCOMMIT後 | A | 新しい星の本 | (0,2) |
| 確定後のVACUUM後 | A | 新しい星の本 | (0,2) |

VACUUM (VERBOSE)の`tuples:`行（`mvcc_books`本体）：

| VACUUMの時点 | `tuples:`行 |
| --- | --- |
| BのCOMMIT前 | `tuples: 0 removed, 1 remain, 0 are dead but not yet removable` |
| BのCOMMIT後 | `tuples: 1 removed, 1 remain, 0 are dead but not yet removable` |

COMMIT前のVACUUMは何も片付けなかった。ただし想定していた`0 removed, 2 remain`ではなく、`1 remain`だった。ログの数値はそのまま記録している。COMMIT前のBが作った新しい版（0,2）は、まだ確定していない挿入として`remain`の数に入らなかったとみられるが、この点はこの実験だけでは確かめていない。COMMIT後は`1 removed, 1 remain`で、古い版（0,1）が片付けられた。

## 第2部：実行中のSELECTが古い版を残す

手順は、TRUNCATEしてINSERTし直したあと、Aが`SELECT id, title, ctid, pg_sleep(30) FROM mvcc_books WHERE id = 42;`を実行し、2秒後にBが`UPDATE`（BEGINなし、autocommit）してVACUUMする。

| 時刻 | 操作 |
| --- | --- |
| 21:18:18 | Aの`pg_sleep(30)`付きSELECTを送る（待たずに次へ） |
| 21:18:20 | BのUPDATE（確定済み） |
| 21:18:20 | BのVACUUM (VERBOSE)（Aの SELECT は実行中） |
| 21:18:48 | AのSELECTの出力を受け取り、BのVACUUM (VERBOSE) |

`tuples:`行：

| VACUUMの時点 | `tuples:`行 |
| --- | --- |
| Aの SELECT 実行中 | `tuples: 0 removed, 2 remain, 1 are dead but not yet removable` |
| AのSELECT終了後 | `tuples: 1 removed, 1 remain, 0 are dead but not yet removable` |

AのSELECTの出力：

```
 id | title  | ctid  | pg_sleep 
----+--------+-------+----------
 42 | 星の本 | (0,1) | 
(1 row)
```

`pg_sleep`列の値は空で表示される（`pg_sleep`が返す値はvoidのため）。Bの更新は確定していたが、AのSELECTはその開始時点の基準で読むので、古い版「星の本」（0,1）を返した。AのSELECT終了後にBがVACUUMすると古い版が片付けられ、Aの新しいSELECTは「新しい星の本」（0,2）を返した。

## 比較の条件と限界

- 本42「星の本」は独立した通常のテーブルで観察した。
- VACUUMはトランザクション外で実行している。
- 想定と違った点は第1部のCOMMIT前のVACUUMの`remain`の数だけ（想定2、実測1）。assertは`tuples: 0 removed`だけにしてある。
- 時刻はスクリプトの`time.strftime`による。

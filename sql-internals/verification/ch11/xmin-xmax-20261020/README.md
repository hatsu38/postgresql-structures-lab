# 第11章：レコードに付いたトランザクションの番号（xmin・xmax）を見る二接続実験

2026-10-20に実施。第11章のスナップショットの節で、レコードに「作ったトランザクションの番号」と「書き換えたトランザクションの番号」が付いていることを、実際の値で示すために行った。手順は[ch11-two-sessions-rc-20261019](../ch11-two-sessions-rc-20261019/README.md)の第1部と同じで、SELECTに`xmin`・`xmax`の列を足し、BのUPDATE後に`pg_current_xact_id()`でBのトランザクションの番号を取った。VACUUMはしていない。

## 環境

- 専用一時コンテナ：`claude-pg-ch11-xmin-20261020`。ポート公開なし、既存ボリュームの接続なし。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`（ch11-two-sessions-rc-20261019と同じ）
- PostgreSQL 18.6（Debian 18.6-1.pgdg13+2）、aarch64。
- DB名はreading_map、default_transaction_isolation=read committed。
- `mvcc_books`だけautovacuum_enabled=false。Aは一度もBEGINしていない（autocommit）。

## 保存ファイルと再現手順

1. xmin-xmax.py：二つのpsqlプロセスへSQLを送り、操作順と結果を記録する。題名・ctid・xmin・xmaxと、Bの番号との一致をassertで確認する。
2. xmin-xmax.log：xmin-xmax.pyの出力。

```sh
docker run --detach --rm --name claude-pg-ch11-xmin-20261020 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec claude-pg-ch11-xmin-20261020 pg_isready -U postgres -d reading_map
python3 -I xmin-xmax.py > xmin-xmax.log 2>&1
docker stop claude-pg-ch11-xmin-20261020
```

## 結果

BのUPDATEのトランザクションの番号（`pg_current_xact_id()`）は756。

| 時点 | 接続 | 見えた題名 | ctid | xmin | xmax |
| --- | --- | --- | --- | --- | --- |
| INSERT直後 | A | 星の本 | (0,1) | 755 | 0 |
| BのUPDATE後、COMMIT前 | B（自分の更新） | 新しい星の本 | (0,2) | 756 | 0 |
| BのUPDATE後、COMMIT前 | A | 星の本 | (0,1) | 755 | 756 |
| BのCOMMIT後 | A | 新しい星の本 | (0,2) | 756 | 0 |

- 元のレコード(0,1)のxminは、AのINSERTのトランザクションの番号755。
- BがUPDATEすると、元のレコード(0,1)のxmaxにBの番号756が書き込まれた。COMMIT前でも、Aから見たxmaxは756だった。
- 新しいレコード(0,2)のxminはBの番号756。

## 比較の条件と限界

- 番号の値（755・756）は、新しく作ったDBでの値で、環境や操作の履歴によって変わる。ch11-two-sessions-rc-20261019のVACUUMの出力にある`removable cutoff: 756`とは別の実験で、番号どうしを比べてはいない。
- 2つのレコードを同時に並べて見るには`pageinspect`拡張が要るため、ここではAとBそれぞれに見えるレコードの値だけを記録した。

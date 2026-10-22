# 第3章の実測（2026-10-04）

題名Indexを作る前後の同じ検索と、番号の範囲検索を、新しい一時DBで実行した。本文の数値は今回のログを使った。

## 環境と前提

- PostgreSQL 18.6、Debian、aarch64。照合順序はlibcのen_US.utf8。
- イメージは `postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`。
- block_size=8192、shared_buffers=128MB、work_mem=4MB。並列実行とJITは無効。
- 専用コンテナ `codex-pg-sql-internals-ch3-20261004` を使用。既存のDB・ボリュームは使用せず、ホストへのポート公開もしていない。
- 第1章のsetup.sqlをそのままコピーした。本100万冊、読書記録200万件。SHA-256は `9edb7ba8b2a9f847da3c37e27e9070d1473c95828a3db3b413390a55e5012ee1`。
- 第2章の補助テーブルは不要なため作っていない。booksは第2章で更新しない前提と同じ初期状態で、主キーのIndexだけがある。

## 入力と出力

- [setup.sql](setup.sql)と[setup.log](setup.log)：初期データの作成。
- [observe.sql](observe.sql)と[observe.log](observe.log)：共通設定、Index一覧、作成前の検索、Index作成、ANALYZE、作成後の検索、範囲検索、容量確認。

以下はリポジトリのルートから実行する。ログを再保存するときは別名にする。

```sh
docker run --detach --rm --name codex-pg-sql-internals-ch3-20261004 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec codex-pg-sql-internals-ch3-20261004 pg_isready -U postgres -d reading_map
```

接続を受け付ける状態になってから、続けて実行する。

```sh
docker exec -i codex-pg-sql-internals-ch3-20261004 psql -X -U postgres -d reading_map -a \
  < _drafts/postgresql-sql-internals/verification/ch03-20261004/setup.sql
docker exec -i codex-pg-sql-internals-ch3-20261004 psql -X -U postgres -d reading_map -a \
  < _drafts/postgresql-sql-internals/verification/ch03-20261004/observe.sql
```

## 結果

| 観察 | 確認した値 |
| --- | --- |
| Index作成前 | Seq Scan、出力1、除外999,999、shared hit=4644 read=2709 |
| Index作成後 | books_title_idxのIndex Scan、Index Condは題名一致、出力1、shared read=4 |
| idの範囲検索 | books_pkeyのIndex Scan、推定10件、実際11件、shared hit=4 read=3 |
| 題名Indexの主フォーク容量 | 40,640,512バイト、pg_size_prettyでは39 MB |

作成後のSELECTで本42を取得できた。範囲検索は別途ORDER BY idを付けたSELECTでも400000〜400010の11件を確認した。

比較は同じDBの一連の実行だが、Index作成とANALYZEを挟むため、キャッシュなどの条件を固定した速度比較とは扱わない。Indexを作る前後で、方法・条件の使われ方・ページアクセスが変わったことを観察する。木の高さや各Indexページの内容を直接測定した実験ではない。

本文の小さな木、架空のctid `(12,5)`、分岐数100の計算例は説明用。旧版にある90万件の範囲検索や、更新のWAL量を測る実験は今回の章に追加していない。

## 終了

観察終了後、今回の専用コンテナを停止する。`--rm`によりコンテナと専用の匿名ボリュームが削除される。読者が各章を続けて実行する環境では、題名Indexは第4章に引き継ぐ。

```sh
docker stop codex-pg-sql-internals-ch3-20261004
```

## 原稿の確認

本文のSQL6文と、掲載した出力の全行を観察SQL・ログに照合した。画像3枚のPNGとSVGはコピー元と同一で、catalog.jsonのハッシュとも一致する。Zennプレビューで新しい章が目次に入り、3枚の図が本文中に表示されることを確認した。専用コンテナは停止済み。

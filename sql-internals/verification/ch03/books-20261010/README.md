# booksでctidとページ数を確認する

第3章の観察用テーブルを廃止し、準備の章と同じbooksを使うために再測定した。既存のデータベースは使わず、専用コンテナに共通の初期データ（本100万冊、読書記録200万件）を作った。観察は読み取り専用トランザクションで行った。

## 環境と再現手順

PostgreSQL 18.6、aarch64、block_size=8192。ホストへのポート公開なし。

```sh
docker run --detach --rm --name codex-pg-ch03-books-20261010 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec codex-pg-ch03-books-20261010 pg_isready -U postgres -d reading_map
```

準備完了後、このディレクトリで実行する。

```sh
docker exec -i codex-pg-ch03-books-20261010 psql -X -U postgres -d reading_map -a < setup.sql
docker exec -i codex-pg-ch03-books-20261010 psql -X -U postgres -d reading_map -a < observe.sql
docker stop codex-pg-ch03-books-20261010
```

setup.sqlは既存のch02-20261004/setup.sqlを変更せずコピーした。setup.logとobserve.logに実行結果を保存した。

## 結果と本文への反映

- booksは100万件。テーブル本体は60,235,776バイト、7,353ページ。
- 本1〜5のctidは(0,1)〜(0,5)。既存のctidの図と一致。
- 先頭8ページは各136件。本1〜136、137〜272、273〜408、409〜544、545〜680、681〜816、817〜952、953〜1088。
- 最終ページ7352は128件。本999873〜1000000。
- 図3.3はテーブル全体ではなく、先頭8ページの抜粋に変更した。

コンテナは測定後に停止した。保存ページ数とctidを調べる実験であり、ディスクアクセスの回数や速度は測定していない。

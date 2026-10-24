# 第11章：猫の血液型テーブル cats の UPDATE・VACUUM 前後のページ数の実測記録

第11章の「第10章でページが64から99に増えた理由」の節で使う、UPDATE・VACUUM前後のページ数とVACUUMの全出力です。第10章の検索・統計の更新は[猫の実験](../../cats-sample/README.md)で確認できます。

## 環境

- 専用の一時コンテナ：`claude-pg-ch11-cats-vacuum`。ポート公開なし、既存ボリュームの接続なし。実行後に停止（`--rm` で削除）。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`（PostgreSQL 18.6、Debian 18.6-1.pgdg13+2、aarch64）
- max_parallel_workers_per_gather=0、jit=off、work_mem=4MB、block_size=8192。
- `cats` は `autovacuum_enabled = false` で作った。測定の途中で autovacuum が走らないようにするため。トランザクションで囲まず、各文を autocommit で確定させた。

## 再現手順

```sh
docker run --detach --rm --name claude-pg-ch11-cats-vacuum \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec -i claude-pg-ch11-cats-vacuum psql -X -a -U postgres -d reading_map < observe.sql > observe.log 2>&1
docker stop claude-pg-ch11-cats-vacuum
```

VACUUM VERBOSE の出力は stderr に出るので `2>&1` が必要。

## 確認した結果（observe.log）

| 観察 | 値 |
| --- | ---: |
| 作成直後のページ数（pages / relpages / reltuples） | 64 / 64 / 10000 |
| UPDATE 8,000件後のページ数（pages / relpages） | 99 / 64 |
| VACUUM 後のページ数（pages / relpages） | 99 / 99 |
| 2回目の UPDATE（8,000件）後のページ数（pages / relpages） | 99 / 99 |
| VACUUM VERBOSE の `pages:` 行 | 0 removed, 99 remain, 99 scanned (100.00% of total), 0 eagerly scanned |
| VACUUM VERBOSE の `tuples:` 行 | 8000 removed, 10000 remain, 0 are dead but not yet removable |
| VACUUM 前の n_live_tup / n_dead_tup（observe.log） | 10000 / 0 |
| VACUUM 後の n_live_tup / n_dead_tup（observe.log） | 10000 / 0 |

UPDATEは元のレコードを残して新しいレコードを作るため、更新直後にはページ数が64から99へ増えます。更新をCOMMITし、元のレコードが不要になっていれば、VACUUMは8,000件を片付けられます。

VACUUM はページ数を減らさなかった（pages: 0 removed、99 remain）。片付けた領域は空き領域として残り、2回目の UPDATE ではその領域が再利用されてページ数は99のまま増えなかった。

### n_dead_tup の値についての注意

`observe.log` の VACUUM 前の `n_dead_tup` は 0 になっている。UPDATE の直後に psql から続けて問い合わせると、統計情報の更新が間に合っておらず、実際の値を反映していない。待ちを入れて取り直した補足の測定（`observe-stats-wait.sql` / `observe-stats-wait.log`、UPDATE と VACUUM の後に `pg_sleep(1.5)` を入れた）では次のとおりだった。

| 観察 | n_live_tup / n_dead_tup |
| --- | ---: |
| UPDATE 8,000件の後（1.5秒待ち） | 20000 / 8000 |
| VACUUM 後（1.5秒待ち） | 10000 / 0 |

本文で「VACUUM 前の n_dead_tup」を示すなら、こちらの補足の値（8000）を使うのが正しい。

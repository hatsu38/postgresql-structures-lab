# 準備済みの猫のデータで検索と統計の更新を見る

`sql/cats.sql`で猫1万匹と血液型のIndex・統計を用意し、新しい接続から[observe.sql](observe.sql)を実行した全出力を[observe.log](observe.log)に残しています。PostgreSQLは、`compose.yaml`と同じ18.6を使っています。

| 段階 | データと統計 | 選ばれた検索方法 |
| --- | --- | --- |
| 初期状態 | A型9,000件・B型1,000件、統計も同じ割合 | A型はSeq Scan、B型はIndex Scan |
| 8,000件をB型へ更新 | 実際はB型9,000件、統計はB型1割のまま | B型はIndex Scan、推定1,547件・実測9,000件 |
| ANALYZE後 | 統計もB型9割へ更新 | B型はSeq Scan、推定・実測とも9,000件 |

検索方法を切り替える`SET`は使いません。統計が自動更新されないよう、初期化で`cats`だけ自動バキュームを止めています。

## 再実行する

実験用リポジトリのルートで実行します。初期化コマンドは`cats`とそのIndex・統計だけを作り直し、更新前の状態へ戻します。`-1`で作り直しを1つのトランザクションにまとめます。

```sh
docker compose exec -T db psql -X -1 -v ON_ERROR_STOP=1 -U postgres -d reading_map -f /lab/sql/cats.sql
docker compose exec -T db psql -X -a -v ON_ERROR_STOP=1 -U postgres -d reading_map < sql-internals/verification/cats-sample/observe.sql
```

実行後は、A型1,000件・B型9,000件と、その割合の統計が残ります。もう一度試すときや、第11章の猫の実験を始めるときは、最初のコマンドから実行してください。

このログは、第10章の検索と統計の更新を確認するものです。選ばれなかったScanのcostとIndexの内訳は[第10章の比較ログ](../ch10/cats-20261018/README.md)、VACUUMの比較は[第11章のログ](../ch11/cats-vacuum-20261019/README.md)にあります。

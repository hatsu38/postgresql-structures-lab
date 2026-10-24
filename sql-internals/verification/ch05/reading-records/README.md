# 第4章・読了日時での検索

著者の希望で、題名の文字列範囲検索を「9月20日に読み終えた本の記録」の検索へ変更した。第4章のキャッシュ実験も同じ環境で測り直し、本文のSQL出力はすべて今回のログに合わせた。変更前の題名検索のログは、隣のch05-scan-methodsに保存している。

## 環境

- PostgreSQL 18.6、Debian、aarch64。DBはlibcのen_US.utf8。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`。
- block_size=8192、shared_buffers=128MB、work_mem=4MB。並列実行・JITは無効。
- 専用コンテナ `codex-pg-ch4-reading`。既存DB・ボリュームは使わず、ホストへのポート公開なし。
- 共通の本100万冊・読書記録200万件。setup.sqlは従来と同一で、SHA-256は`9edb7ba8b2a9f847da3c37e27e9070d1473c95828a3db3b413390a55e5012ee1`。

## SQLとログ

| 入力 | 出力 | 役割 |
| --- | --- | --- |
| [setup.sql](setup.sql) | [setup.log](setup.log) | 共通データを作成 |
| [prepare.sql](prepare.sql) | [prepare.log](prepare.log) | 第3章の題名Indexと第2章の観察表を準備 |
| [observe.sql](observe.sql) | [observe.log](observe.log) | キャッシュ3回、読了日時Index作成、日時順のctid、三方式の測定 |
| [check.sql](check.sql) | [check.log](check.log) | 結果一致・設定復元・日時Indexと観察表の削除を確認 |

再現時は、リポジトリのルートから次のコマンドで専用DBを作り、pg_isreadyが接続可能を返すまで待つ。

```sh
docker run --detach --rm --name codex-pg-ch4-reading \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec codex-pg-ch4-reading pg_isready -U postgres -d reading_map
```

接続可能になった後、setup、prepare、observe、checkの順に実行する。既存の保存ログには上書きしない。

```sh
for chapter_step in setup prepare observe check; do
  docker exec -i codex-pg-ch4-reading psql -X -U postgres -d reading_map -a \
    < "sql-internals/verification/ch05/reading-records/${chapter_step}.sql" || break
done
```

## 結果

| 観察 | 結果 |
| --- | --- |
| キャッシュ実験 | 1,000件・8ページ。初回read=8、2・3回目hit=8。出力1・除外999はすべて同じ |
| 日時順の先頭4件のページ | 1401→6054→10708→2285 |
| 対象の記録 | 9月20日0時以上、21日0時未満の71,427件 |
| 既定の計画 | Bitmap Heap Scan＋Bitmap Index Scan。exact=10811、lossyなし |
| Bitmap上段 | hit=10815 read=194、合計11,009回（子のIndexを含む） |
| Bitmap下段 | hit=4 read=194、合計198回 |
| Index Scan | hit=71625、出力71,427 |
| Seq Scan | hit=10811、出力71,427、除外1,928,573 |
| 対象が存在するページ／テーブル全体 | 10,811／10,811ページ |
| 結果一致 | 本番号と読了日時を、重複込みの双方向EXCEPT ALLで比較。Bitmap対Index、Bitmap対Seqとも差分0 |
| 終了状態 | 日時Index・観察表なし。booksの主キーIndexと題名Indexを維持。三方式on、work_mem=4MB |

Bitmapは設定で強制せず選ばれた。Index ScanとSeq Scanの比較はSET LOCALによる設定変更を使い、ROLLBACKで戻した。結果比較でも、それぞれの設定下で実際の計画を確認した。

今回は対象が全ページに散らばっているため、Bitmapのテーブル取得回数はSeq Scanと同じ。BitmapはIndexを読む198回が余分にある。本文では、Bitmapが常にSeq Scanより少ないページを読むとは説明せず、Index Scanの繰り返しアクセス、Seq Scanの全件の条件比較との違いを示した。

三方式はBitmap→Index→Seqの順に一回ずつ測定した。キャッシュを同条件にした速度比較ではない。OSキャッシュの追い出しもしていない。

## 原稿と後片付け

本文のSQL22文・掲載出力45行・計算を今回のログに照合した。Zennプレビューでも、読了日時の例への切り替えとSQLの表示を確認した。小さなビットマップの例と図は変更していない。日時Indexは第4章内で削除し、第5章のソート実験へ持ち越さない。

専用コンテナは次のコマンドで停止済み。--rmにより専用の匿名ボリュームも削除される。

```sh
docker stop codex-pg-ch4-reading
```

# 第10章：MVCC・VACUUM・Index Only Scanの実測記録

2026-10-04に実施。二つのpsql接続を順番に操作し、Read CommittedとRepeatable Readの見え方を比較した。後半は読書記録の複製で、更新・VACUUMとHeap Fetchesを観察した。原稿の出力は今回の実測であり、旧版の数値は転記していない。

## 環境

- 専用一時コンテナ：`codex-pg-ch10-20261004`。ポート公開なし、既存ボリュームの接続なし。
- イメージ：`postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae`
- PostgreSQL 18.6（Debian 18.6-1.pgdg13+2）、aarch64。version全文はprepare.log。
- reading_map、en_US.utf8、block_size=8192、shared_buffers=128MB。
- 後半はmax_parallel_workers_per_gather=0、jit=off、work_memは既定の4MB。
- 共通の本100万件・読書記録200万件と、第8章までのIndexを再作成。pg_buffercacheも前章と同じ準備に含まれるが、今回使っていない。
- 観察用の通常テーブル2個だけautovacuum_enabled=false。主データの設定は変更しない。
- 二接続の確定・未確定を明示し、Repeatable Readの最初のSELECTがBの更新より先になるよう、各操作の出力が完了してから次へ進めた。

## 保存ファイルと再現手順

1. setup.sql／setup.log：共通データの生成。
2. prepare.sql／prepare.log：Index作成・ANALYZE・環境確認。
3. two-sessions.py／two-sessions.log：二つのpsqlプロセスへSQLを送り、操作順と結果を記録。見える題名をassertで確認。
4. visibility.sql／visibility.log：読書記録を複製し、VACUUM・更新・VACUUMの前後を比較。
5. cleanup.sql／cleanup.log：観察用テーブルを削除し、主データの件数、本42の題名と読了日時を確認。
6. check-manuscript.py／check-manuscript.log：本文のSQL・出力と保存ログの照合、図の参照先・ハッシュの確認。

setup.sqlのSHA-256：`9edb7ba8b2a9f847da3c37e27e9070d1473c95828a3db3b413390a55e5012ee1`。

```sh
docker run --detach --rm --name codex-pg-ch10-20261004 \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=reading_map \
  postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae
docker exec codex-pg-ch10-20261004 pg_isready -U postgres -d reading_map
```

接続可能になったら、このフォルダで以下を順番に実行する。各コマンドの完了を待ち、特にprepareと二接続の実験を並行させない。別の長い処理がスナップショットを保持していると、Aの終了後もVACUUMが版を回収できない場合がある。

```sh
docker exec -i codex-pg-ch10-20261004 psql -X -a -v ON_ERROR_STOP=1 -U postgres -d reading_map < setup.sql > setup.log 2>&1
docker exec -i codex-pg-ch10-20261004 psql -X -a -v ON_ERROR_STOP=1 -U postgres -d reading_map < prepare.sql > prepare.log 2>&1
python3 two-sessions.py > two-sessions.log 2>&1
docker exec -i codex-pg-ch10-20261004 psql -X -a -v ON_ERROR_STOP=1 -U postgres -d reading_map < visibility.sql > visibility.log 2>&1
docker exec -i codex-pg-ch10-20261004 psql -X -a -v ON_ERROR_STOP=1 -U postgres -d reading_map < cleanup.sql > cleanup.log 2>&1
python3 check-manuscript.py > check-manuscript.log
docker stop codex-pg-ch10-20261004
```

照合スクリプトは今回のログと原稿の一致を検査するもの。別環境ではctidや回収状態などが変わり得るため、測定し直した場合は、その結果を確認して原稿と照合条件も見直す。

## 二接続で確認した結果

| Aが読む時点 | Read Committed | Repeatable Read |
| --- | --- | --- |
| AのBEGIN後、最初のSELECT | 星の本、(0,1) | 星の本、(0,1) |
| BのUPDATE後、未確定 | 星の本、(0,1) | 星の本、(0,1) |
| BのCOMMIT後、Aはまだトランザクション内 | 新しい星の本、(0,2) | 星の本、(0,1) |
| AもCOMMIT後、新しいSELECT | 新しい星の本、(0,2) | 新しい星の本、(0,2) |

B自身はUPDATE後・COMMIT前にも新しい星の本と(0,2)が見えた。二つの分離レベルはTRUNCATE・INSERTで初期状態を戻してから、別々に試した。

Repeatable ReadのAが古い版を読んでいる間、BでVACUUM (VERBOSE)を行うと、`0 removed, 2 remain, 1 are dead but not yet removable`だった。その後もAは古い値を読めた。AがCOMMITした後のVACUUMでは、`1 removed, 1 remain, 0 are dead but not yet removable`となった。

補助確認では、AがRepeatable ReadのBEGINだけ実行し、Bが更新・COMMITした後にAが最初のSELECTを実行した。この場合は新しい題名が見え、BEGINだけではスナップショットが固定されないことを確認した。さらにBの更新をROLLBACKすると、元の確定した題名へ戻ることも確認した。補助確認の出力は本文には載せていない。

## Index Only Scanと可視性マップ

`mvcc_reading_records`は主データ200万件の複製。本42は1件で、初期日時は2026-08-29 02:29:54、ctidは(4428,6)。日時を1秒進めると2026-08-29 02:29:55、ctidは(10810,151)となった。

| 状態 | 返した件数 | Heap Fetches | ページ4428のall-visible | ページ10810のall-visible |
| --- | ---: | ---: | --- | --- |
| VACUUM後 | 1 | 0 | true | true |
| 日時のUPDATE・COMMIT後 | 1 | 2 | false | false |
| 再びVACUUM後 | 1 | 0 | false | true |

三つとも通常選択されたIndex Only Scanで、scanを強制する設定は使用していない。計画のcost・actual time・Buffersもvisibility.logへ保存した。本文は今回の説明に必要な処理名、Index Cond、Heap Fetchesを抜粋している。

可視性の補助確認にはpg_visibility拡張のpg_visibility_mapを使用した。二つのページ番号は先行観察で得た配置に基づく。別のデータ配置で再現する場合は、実際のctidのページ番号を確認してから変更する。pg_visibilityのクエリは原稿には入れていない。

最後のVACUUM後、古い版のページ4428の印はfalseのままだった。旧版の図は両ページに印が戻るため流用せず、新しい版のページの印と残ったIndex項目だけを説明する図を作成した。Heap Fetches=0から「全ページに印が付いた」とは推論しない。

## 比較の条件と限界

- 本42「星の本」は独立した通常のテーブルで観察。TEMP TABLEは接続間で共有できないので使わない。
- Aは読み取りのみ、通常のSELECTで観察した。更新の競合、SELECT FOR UPDATE、分離レベル全体の網羅には広げない。
- VACUUMはトランザクション外で実行。古い版を必要とする読み手が消えることは、回収可能になるための条件であり、他の長いトランザクションなども影響する。
- MVCCは新旧の版とスナップショットで説明し、xmin/xmaxの判定式や内部フラグまでは扱わない。番号の大小だけで可視性が決まるとも説明しない。
- 後半はIndexに含むfinished_atを実際に変えている。単に同じ値を代入する更新とは異なり、Index項目の追加が必要になる。
- 0→2→0は今回の結果であり、更新全般に固定された回数ではない。途中のテーブルアクセスや保守のタイミングにも影響される。
- 主データのbooksとreading_recordsへの更新文はない。後片付け時に100万件・200万件、本42の元の題名と日時が残っていることを確認。

## 一次資料

- [MVCCの概要](https://www.postgresql.org/docs/18/mvcc-intro.html)
- [Read Committed・Repeatable Read](https://www.postgresql.org/docs/18/transaction-iso.html)
- [ctidとレコードの版](https://www.postgresql.org/docs/18/ddl-system-columns.html)
- [VACUUMによる領域の回収](https://www.postgresql.org/docs/18/routine-vacuuming.html)
- [Index Only Scanの可視性確認](https://www.postgresql.org/docs/18/indexes-index-only-scans.html)

## 原稿・図の確認

本文のSQL40文、掲載出力65行を実行ログと照合した。二接続の見え方、VACUUMの回収、Heap Fetches、可視性マップの三時点、後片付けも照合済み。

図10.1は旧版からPNG・SVGをそのままコピー。図10.2〜10.4は今回の実験に合わせてMermaidで作成した。原本と描画設定、PNG・SVG、ハッシュを保存している。図10.2の長い注記は改行を調整し、文字のはみ出しを修正した。

natural-japaneseのquickモードで推敲。繰り返す「ここで」を具体的な主語へ直し、「の」が続く文を整理した。最終lintは語彙多様性の指摘だけが残り、版・接続・更新などの用語を一貫して使うため保持。読解負荷の指摘は0件。見出しと段落先頭文も通読し、観察→版とスナップショット→回収→Indexの可視性確認の順序を確認した。

Zennプレビューで図4枚の読み込み、時系列図、VACUUMの図、Index Only Scanの図と比較表、改行した計画を確認した。MVCCの太字が文字として残っていた箇所も、表示を見て修正した。

ログ保存と照合の後、専用一時コンテナ`codex-pg-ch10-20261004`を停止した。`--rm`で作成したため、コンテナと実験用DBも削除された。

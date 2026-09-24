# 100万冊から始める版の実行条件

- 実行日：2026-09-23（日本時間）
- PostgreSQL：18.6 (Debian 18.6-1.pgdg13+2)、aarch64。compose.yamlのイメージを使用。
- 既存コンテナ内に検証専用DB `journey_million_20260923` を新設。利用中の `reading_map` は変更していない。
- 初期データ：books 1,000,000行、reading_records 2,000,000行。
- 第1・2章はbooks_pkeyのみ。並列実行・JITを無効化、work_mem=4MB、shared_buffers=128MB。
- 第2章ではsynchronize_seqscans=offとし、末尾でRESET。
- セットアップ → 初期データ検査 → 第1章 → 第2章 → 追加観察の順に実行。
- 各EXPLAIN ANALYZEは1回。キャッシュを空にしておらず、平均や中央値ではない。

| ファイル | 内容 |
| --- | --- |
| setup-million-2026-09-23.txt | 初期データの作成と件数 |
| check-million-2026-09-23.txt | 件数・検索対象・参照整合性・初期索引の検査 |
| chapter01-million-2026-09-23.txt | 第1章の設定・SQL・実行計画 |
| chapter02-million-2026-09-23.txt | 同じ100万冊でLIMITの有無と題名を比較 |
| million-followup-2026-09-23.txt | 序章のランキング、初期容量、題名索引作成後の第6章の計画、第7章の件数 |

本文の計画は、元ログからQUERY PLANの見出し・罫線・末尾行数と表示用の先頭空白を除いて転載している。実行時間とBUFFERSは書き換えていない。初期容量は本と主キー索引79 MB、読了記録85 MB、DB全体171 MB。WALや後続の索引・一時ファイルの容量は別に必要。セットアップ所要時間は今回計測していない。

旧版のログは下記の条件による履歴として保持する。現在の初期データとは混同しない。

## 旧版：1,000冊の実行条件

- 実行日：2026-09-22（日本時間）
- PostgreSQL：18.6 (Debian 18.6-1.pgdg13+2)、aarch64
- Docker Engine環境：Linux/aarch64、10 CPU、メモリ8,217,448,448バイト（割り当て値）
- 公式イメージのdigestはcompose.yamlに固定
- 初期データ：books 1,000行、reading_records 20,000行
- booksの索引：books_pkeyのみ。題名の索引なし
- shared_buffers=128MB、work_mem=4MB、max_parallel_workers_per_gather=2、jit=on
- 新しい専用ボリュームで起動し、00-setup.sql → 02-check.sql → 01-observe.sqlの順に実行
- 01-observe.sql内では件数確認 → SELECT → EXPLAIN → 題名のANALYZE → 番号のANALYZE → 該当なしのANALYZEの順
- 各EXPLAIN ANALYZEは1回。キャッシュを空にする操作はしていない。平均値・中央値ではない

`chapter01-2026-09-22.txt`は `psql -X -a` の標準出力を保存した元ログです。本文ではQUERY PLANの見出し・罫線・末尾の行数表記だけ省き、計画の全行を掲載しています。時間やBUFFERSの数値は書き換えていません。

この小さなデータでの時間差から、一般的な速度比は主張しません。観察の中心は、Seq ScanとIndex Scan、返した行数と除外行数の違いです。

# 第1章の実行条件

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

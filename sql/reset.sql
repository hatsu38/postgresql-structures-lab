-- 実験用DBを、00-setup.sql を実行した直後の状態へ戻す。
-- 本の中で作ったテーブル・Index・拡張と、書き換えたデータをすべて消してから、初期データを入れ直す。
\set ON_ERROR_STOP on

-- 同じDBへの他の接続を切る。第11章の接続A・Bなどが残っていると、ロック待ちで止まるため。
SELECT count(pg_terminate_backend(pid)) AS terminated_connections
FROM pg_stat_activity
WHERE datname = current_database()
  AND pid <> pg_backend_pid();

-- public スキーマごと消し、PostgreSQL 15 以降の初期設定と同じ所有者・権限で作り直す。
DROP SCHEMA public CASCADE;
CREATE SCHEMA public AUTHORIZATION pg_database_owner;
GRANT USAGE ON SCHEMA public TO PUBLIC;

\ir 01/00-setup.sql
\ir 01/02-check.sql

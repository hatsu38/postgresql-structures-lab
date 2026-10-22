# 図1.2の構文木の確認

pglast 8.5に組み込まれたPostgreSQL 18.6のパーサで、query.sqlを構文解析した。データベースへの問い合わせや名前・型のチェックは行っていない。

再現方法:

```sh
uv run --with pglast==8.5 python -c 'from pathlib import Path; from pglast import parser; print(parser.parse_sql_json(Path("query.sql").read_text()))'
```

parse-tree.jsonが取得した構文木。検証資料として保存した01-syntax-tree-detailsの図（本文には未掲載）はSelectStmt以下のtargetList・fromClause・whereClauseを抜粋している。ResTargetとColumnRef、A_Exprの左右の子の関係を保ち、リストは枝分かれで表した。ColumnRef.fieldsのStringやA_Expr.nameは箱の中の値として示した。RawStmt、SQL内の文字位置、今回使わない項目は省略した。日本語は説明のために添えた。

2026-10-11に図1.2（01-syntax-tree）を簡略化し、SQLの列・テーブル・条件との対応を同じ色で示した。内部名を日本語の役割に置き換え、targetListの2つの要素を「取り出す列」の1つの枠にまとめた。検索条件の左右の子の関係は保っている。構文解析の結果そのものは変更していない。

参照:
- [日本語ドキュメント：構文解析過程](https://www.postgresql.jp/document/18/html/parser-stage.html)
- [PostgreSQL 18のノード定義](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/include/nodes/parsenodes.h)

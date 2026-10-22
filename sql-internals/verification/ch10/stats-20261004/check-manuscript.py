"""原稿に掲載したSQL・出力・計算・画像を、保存済みの実測ログと照合する。"""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
chapter = ROOT / 'books/postgresql-sql-internals/09-planner-and-statistics.md'
text = chapter.read_text()
log = (HERE / 'observe.log').read_text()
script = (HERE / 'observe.sql').read_text()


def normalized(value):
    return re.sub(r'\s+', ' ', value).strip()


normalized_log = normalized(log)
output_lines = []
for block in re.findall(r'```sql:実行結果\n(.*?)```', text, re.S):
    for line in block.splitlines():
        line = line.strip()
        if not line or line == '…':
            continue
        assert normalized(line) in normalized_log, f'ログにない出力: {line}'
        output_lines.append(line)
print(f'PASS: 掲載出力 {len(output_lines)} 行を実測ログと照合（空白・折り返しのみ正規化）')

queries = []
for block in re.findall(r'```sql\n(.*?)```', text, re.S):
    lines = []
    for line in block.splitlines():
        if line.startswith('\\'):
            assert line in script
        else:
            lines.append(line)
    for statement in '\n'.join(lines).split(';'):
        if statement.strip():
            query = normalized(statement) + ';'
            assert query in normalized(script), f'実験SQLにない文: {query}'
            queries.append(query)
print(f'PASS: 掲載SQL {len(queries)} 文を実行済みスクリプトと照合')

assert not re.search(r'ERROR:|FATAL:', log)
plans = re.findall(
    r'(Seq Scan on stats_demo|Index Scan using stats_demo_category_idx on stats_demo)\s+'
    r'\(cost=([\d.]+)\.\.([\d.]+) rows=(\d+) width=(\d+)\)'
    r'(?: \(actual time=[\d.]+\.\.[\d.]+ rows=([\d.]+) loops=1\))?', log)
assert len(plans) == 7, plans
assert [(p[0].split()[0], p[2], int(p[3])) for p in plans] == [
    ('Seq','189.00',9000), ('Index','35.78',1000),
    ('Index','258.79',9000), ('Seq','189.00',1000),
    ('Seq','189.00',2499), ('Index','51.55',1672), ('Seq','232.00',9000)]
assert float(plans[0][5]) == 9000
assert float(plans[1][5]) == 1000
assert float(plans[4][5]) == sum(n < 2500 for n in range(1, 10001))
assert float(plans[5][5]) == float(plans[6][5]) == 9000
assert 64 + 10000 * .01 + 10000 * .0025 == float(plans[0][2])
assert 107 + 10000 * .01 + 10000 * .0025 == float(plans[6][2])
assert round(10000 * 107 / 64 * .1) == int(plans[5][3])
print('PASS: 7計画の方法・cost・推定件数、5計画の実測件数、costとページ補正の手計算')

assert re.search(r'\{popular,rare\}\s*\|\s*\{0\.9,0\.1\}', log)
assert re.search(r'\{rare,popular\}\s*\|\s*\{0\.9,0\.1\}', log)
assert '{1,1000,2000,3000,4000,5000,6000,7000,8000,9000,10000}' in log
assert re.search(r'n_distinct\s*\n-+\s*\n\s*77812', log)
assert 'rows=77812 width=16' in log
assert re.search(r'actual_groups\s*\n-+\s*\n\s*736097', log)
assert re.search(r'demo_removed\s*\n-+\s*\n\s*t', log)
for setting in ['enable_seqscan', 'enable_indexscan', 'enable_bitmapscan']:
    assert re.search(rf'{setting}\s*\n-+\s*\n\s*on', log)
print('PASS: MCVの更新、ヒストグラム、グループ数、実験テーブル削除と設定復元')

assert hashlib.sha256((HERE / 'setup.sql').read_bytes()).hexdigest() == '9edb7ba8b2a9f847da3c37e27e9070d1473c95828a3db3b413390a55e5012ee1'
for path in re.findall(r'!\[[^\]]*\]\((/images/[^)]+)\)', text):
    assert (ROOT / path.lstrip('/')).is_file(), path
catalog = json.loads((ROOT / 'images/postgresql-sql-internals/catalog.json').read_text())
entry = next(item for item in catalog if item['name'] == '09-stats-to-rows')
for extension, subdir in [('png',''),('svg','sources/')]:
    target = ROOT / f'images/postgresql-sql-internals/{subdir}09-stats-to-rows.{extension}'
    source = ROOT / f'images/postgresql-query-journey/{subdir}10-stats-to-rows.{extension}'
    assert target.read_bytes() == source.read_bytes()
    assert hashlib.sha256(target.read_bytes()).hexdigest() == entry['sha256'][extension]
assert text.count('```') % 2 == 0
assert '  - 09-planner-and-statistics\n' in (ROOT / 'books/postgresql-sql-internals/config.yaml').read_text()
print('PASS: 共通データ生成SQL、図の参照先・原本との一致・ハッシュ、コードフェンス、章登録')

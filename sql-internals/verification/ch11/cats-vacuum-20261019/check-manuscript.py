"""第11章の掲載SQL・出力を、二接続（ch11-two-sessions-rc-20261019）・xmin/xmax（ch11-xmin-xmax-20261020）・可視性（ch10-20261004）・cats（このフォルダ）の実測ログと照合する。"""
from pathlib import Path
import re, json, hashlib
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
chapter = (ROOT / 'books/postgresql-sql-internals/11-mvcc-and-visibility.md').read_text()
old = HERE.parent / 'ch10-20261004'
logs = {name: (old / f'{name}.log').read_text() for name in ['visibility', 'cleanup']}
logs['two-sessions'] = (HERE.parent / 'ch11-two-sessions-rc-20261019' / 'two-sessions.log').read_text()
logs['cats'] = (HERE / 'observe.log').read_text()
logs['xmin-xmax'] = (HERE.parent / 'ch11-xmin-xmax-20261020' / 'xmin-xmax.log').read_text()
flat = lambda s: re.sub(r'\s+', '', s)
all_log = flat('\n'.join(logs.values()))
count = 0
for block in re.findall(r'```sql:実行結果\n(.*?)```', chapter, re.S):
    for line in block.splitlines():
        line = line.strip().rstrip('…').strip()
        if line and line != '…':
            assert flat(line) in all_log, f'出力がログと不一致: {line}'
            count += 1
print(f'PASS: 掲載出力 {count} 行をログと照合')
count = 0
for block in re.findall(r'```sql\n(.*?)```', chapter, re.S):
    for statement in block.split(';'):
        if statement.strip():
            assert flat(statement) + ';' in all_log, f'未実行のSQL: {statement}'
            count += 1
print(f'PASS: 掲載SQL {count} 文を実行ログと照合')
assert re.findall(r'tuples: (\d+ removed, \d+ remain, \d+ are dead but not yet removable)', logs['two-sessions'].replace('tuples: 0 removed, 0 remain, 0 are dead but not yet removable',''))[:4] == ['0 removed, 1 remain, 0 are dead but not yet removable','1 removed, 1 remain, 0 are dead but not yet removable','0 removed, 2 remain, 1 are dead but not yet removable','1 removed, 1 remain, 0 are dead but not yet removable']
assert '| 星の本 | (0,1) | ' in logs['two-sessions'] and 'PASS:' in logs['two-sessions']
assert re.findall(r'Heap Fetches: (\d+)', logs['visibility']) == ['0', '2', '0']
assert 'tuples: 8000 removed, 10000 remain, 0 are dead but not yet removable' in logs['cats']
assert re.findall(r'^\s+(\d+) \|\s+(\d+) \|\s+(\d+)$', logs['cats'], re.M) == [('64','64','10000'),('99','64','10000'),('99','99','10000'),('99','99','10000')]
assert 'visibility map: 81 pages set all-visible' in logs['cats']
assert '| 星の本 | (0,1) |  755 |  756' in logs['xmin-xmax'] and '| 新しい星の本 | (0,2) |  756 |    0' in logs['xmin-xmax'] and 'PASS:' in logs['xmin-xmax']
for name, log in logs.items():
    assert not re.search(r'ERROR:|FATAL:|Traceback', log), name
print('PASS: 二接続のVACUUM 4回（確定前・確定後・SELECT実行中・終了後）・Heap Fetches 0→2→0・catsのページ数64→99→99→99・8000 removed・all-visible 81・xmin/xmax（元のレコード755・756、新しいレコード756・0）')
catalog = json.loads((ROOT / 'images/postgresql-sql-internals/catalog.json').read_text())
by_name = {e['name']: e for e in catalog}
images = re.findall(r'!\[[^\]]*\]\((/images/postgresql-sql-internals/([^)]+))\.png\)', chapter)
for _, name in images:
    png = ROOT / f'images/postgresql-sql-internals/{name}.png'
    assert png.exists(), name
    assert hashlib.sha256(png.read_bytes()).hexdigest() == by_name[name]['sha256']['png'], name
figs = re.findall(r'\*図11\.(\d)', chapter)
assert figs == ['1', '2', '3', '4', '5', '6', '7'], figs
print(f'PASS: 図 {len(images)} 枚の参照先とハッシュ、図番号 11.1〜11.7 の並び')

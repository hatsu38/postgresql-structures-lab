"""掲載SQL・出力と、二接続・可視性の実測結果を照合する。"""
from pathlib import Path
import re, json, hashlib
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
chapter=(ROOT/'books/postgresql-sql-internals/10-mvcc-and-visibility.md').read_text()
logs={name:(HERE/f'{name}.log').read_text() for name in ['two-sessions','visibility','cleanup']}
flat=lambda s:re.sub(r'\s+','',s)
all_log=flat('\n'.join(logs.values()))
count=0
for block in re.findall(r'```sql:実行結果\n(.*?)```',chapter,re.S):
    for line in block.splitlines():
        if line.strip() and line.strip()!='…':
            assert flat(line) in all_log, f'出力がログと不一致: {line}'
            count+=1
print(f'PASS: 掲載出力 {count} 行をログと照合')
count=0
for block in re.findall(r'```sql\n(.*?)```',chapter,re.S):
    for statement in block.split(';'):
        if statement.strip():
            assert flat(statement)+';' in all_log, f'未実行のSQL: {statement}'
            count+=1
print(f'PASS: 掲載SQL {count} 文を実行ログと照合')
assert 'PASS:' in logs['two-sessions']
assert 'tuples: 0 removed, 2 remain, 1 are dead but not yet removable' in logs['two-sessions']
assert 'tuples: 1 removed, 1 remain, 0 are dead but not yet removable' in logs['two-sessions']
assert re.findall(r'Heap Fetches: (\d+)',logs['visibility'])==['0','2','0']
assert len(re.findall(r'actual time=[\d.]+\.\.[\d.]+ rows=1.00 loops=1',logs['visibility']))==3
maps=re.findall(r'blkno \| all_visible\s*\n[-+]+\s*\n\s*4428 \| ([tf])\s*\n\s*10810 \| ([tf])',logs['visibility'])
assert maps==[('t','t'),('f','f'),('f','t')],maps
assert '2026-08-29 02:29:54' in logs['visibility'] and '2026-08-29 02:29:55' in logs['visibility']
assert '(4428,6)' in logs['visibility'] and '(10810,151)' in logs['visibility']
assert re.search(r't\s*\| t',logs['cleanup'])
assert '実験用の本 42' in logs['cleanup'] and '2026-08-29 02:29:54' in logs['cleanup']
assert '1000000' in logs['cleanup'] and '2000000' in logs['cleanup']
for name,log in logs.items():
    assert not re.search(r'ERROR:|FATAL:|Traceback',log),name
print('PASS: 二接続の見え方・VACUUMの回収・Heap Fetches・可視性マップ・主データと後片付け')
catalog=json.loads((ROOT/'images/postgresql-sql-internals/catalog.json').read_text())
images=re.findall(r'!\[[^\]]*\]\((/images/[^)]+)\)',chapter)
assert len(images)==4
for path in images:
    name=Path(path).stem
    entry=next(x for x in catalog if x['name']==name)
    for ext,sub in [('png',''),('svg','sources/')]:
        p=ROOT/f'images/postgresql-sql-internals/{sub}{name}.{ext}'
        assert hashlib.sha256(p.read_bytes()).hexdigest()==entry['sha256'][ext]
        if name=='10-editing-scene':
            assert p.read_bytes()==(ROOT/f'images/postgresql-query-journey/{sub}11-editing-scene.{ext}').read_bytes()
assert '  - 10-mvcc-and-visibility\n' in (ROOT/'books/postgresql-sql-internals/config.yaml').read_text()
assert hashlib.sha256((HERE/'setup.sql').read_bytes()).hexdigest()=='9edb7ba8b2a9f847da3c37e27e9070d1473c95828a3db3b413390a55e5012ee1'
assert chapter.count('```')%2==0
print('PASS: 図4枚の参照とハッシュ・再利用元との一致・章登録・共通データ生成SQL')

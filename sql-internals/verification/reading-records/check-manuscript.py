"""今回更新した本文の抜粋・表・参照先を、採取済みログと照合する。"""
from pathlib import Path
import re
import sys

source = Path(__file__).resolve().parent
book = Path(sys.argv[1]) if len(sys.argv) > 1 else source.parents[3] / 'books/postgresql-explain-algorithms'
# source.parents[3] は原稿リポジトリのルート。
parts = {
    '05-buffers-and-bitmap.md': ('ch05.log', '実行結果から、件数とページ数が分かる部分', '## まとめ'),
    '06-sort.md': ('ch06.log', '## EXPLAINで', '## まとめ'),
    '07-top-n-heap.md': ('ch07.log', '### EXPLAIN ANALYZEで', '表7.4に、'),
}
for name, (log_name, start, end) in parts.items():
    text = (book / name).read_text()
    section = text.split(start, 1)[1].split(end, 1)[0]
    log_lines = [' '.join(line.split()) for line in (source / log_name).read_text().splitlines()]
    count = 0
    for block in re.findall(r'```sql:実行結果\n(.*?)```', section, re.S):
        for line in block.splitlines():
            line = ' '.join(line.split())
            if not line or line == '…':
                continue
            pattern = re.escape(line).replace(re.escape('…'), '.*')
            assert any(re.fullmatch(pattern, actual) for actual in log_lines), (name, line)
            count += 1
    assert count > 0
    print(f'{name}: {count} output lines match {log_name}')

for name in ['00-preface.md', *parts, '08-join.md', '09-aggregate.md', '10-planner-and-statistics.md']:
    text = (book / name).read_text()
    assert not re.search(r'499[,.]?99[89]|71427|71,427|27913|27,913|242\.496|137\.231|75,970|77,812', text), name
    for ref in re.findall(r'`(sql-internals/verification/reading-records/[^`]+)`', text):
        assert (source / ref.rsplit('/', 1)[-1]).exists(), (name, ref)
    for image in re.findall(r'/images/postgresql-explain-algorithms/([^)]*\.png)', text):
        for suffix in ['.svg', '.mmd']:
            original = book.parents[1] / 'images/postgresql-explain-algorithms/sources' / (Path(image).stem + suffix)
            if original.exists():
                assert not re.search(r'499[,.]?998|71,427|77,812|75,970', original.read_text()), original

text = (book / '08-join.md').read_text()
log = (source / 'ch08.log').read_text()
for value in ['loops=500000', 'Index Searches: 500000', 'Batches: 16', 'Disk: 12728kB']:
    assert value in text and value in log, value
text = (book / '09-aggregate.md').read_text()
log = (source / 'ch09.log').read_text()
for value in ['rows=2000000.00', 'rows=736097.00', 'rows=77358', 'Batches: 21', 'Disk Usage: 27752kB']:
    assert value in text and value in log, value
assert re.findall(r'Heap Fetches: (\d+)', (source / 'ch11.log').read_text()) == ['0', '2', '1', '0']
assert 'rows=76011' in (source / 'ch10.log').read_text()
assert '76,011' in (book / '10-planner-and-statistics.md').read_text()
assert re.findall(r'starting merge pass of (\d+) input runs', (source / 'trace.log').read_text()) == ['428', '72', '12', '2']
print('JOIN / aggregate / statistics / trace / visibility / references / figures: PASS')
print('PASS')

"""各方式の結合結果と、結合前の記録を重複も含めて照合する。"""
import csv
import hashlib
import io
import subprocess
from collections import Counter

CONTAINER = 'codex-pg-ch7-20261004'

def run(*args):
    return subprocess.check_output(['docker', 'exec', CONTAINER, *args]).decode()

def rows(name):
    return list(csv.reader(io.StringIO(run('cat', f'/tmp/ch07-{name}.csv'))))

raw = run('psql', '-X', '-q', '-U', 'postgres', '-d', 'reading_map', '-c', """
COPY (SELECT book_id, finished_at FROM reading_records
WHERE finished_at >= timestamp '2026-09-14'
  AND finished_at < timestamp '2026-09-21') TO STDOUT WITH (FORMAT csv);
""")
records = list(csv.reader(io.StringIO(raw)))
expected = Counter((book_id, f'実験用の本 {book_id}', finished_at) for book_id, finished_at in records)
assert len(records) == 499998
for name in ['nested', 'hash', 'merge', 'hash64']:
    result = rows(name)
    assert Counter(map(tuple, result)) == expected, name
    canonical = '\n'.join('\t'.join(row) for row in sorted(result)) + '\n'
    print(name, 'records=', len(result), 'sha256=', hashlib.sha256(canonical.encode()).hexdigest())
latest = rows('latest')
expected_latest = sorted(records, key=lambda row: row[1], reverse=True)[:20]
assert latest == [[book_id, f'実験用の本 {book_id}', finished_at] for book_id, finished_at in expected_latest]
print('latest20: 件数、題名、日時、順序が結合前の最新20件と一致')
print('latest first:', latest[0])
print('latest last:', latest[-1])
print('week distinct books:', len({row[0] for row in records}))
print('全方式で、重複を含む全レコードが結合前の記録と一致')

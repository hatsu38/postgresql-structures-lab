"""SQLとは別にPythonで全記録を数え、両方式の集計結果を確認する。"""
import csv
import hashlib
import io
import subprocess
from collections import Counter

CONTAINER = 'codex-pg-ch8-20261004'

def run(*args):
    return subprocess.check_output(['docker', 'exec', CONTAINER, *args]).decode()

source = run('psql', '-X', '-q', '-U', 'postgres', '-d', 'reading_map', '-c',
             'COPY (SELECT book_id FROM reading_records) TO STDOUT WITH (FORMAT csv);')
expected = Counter(map(int, source.splitlines()))
assert sum(expected.values()) == 2000000
assert len(expected) == 736097
for name in ['hash', 'group']:
    rows = list(csv.reader(io.StringIO(run('cat', f'/tmp/ch08-{name}.csv'))))
    result = {int(book_id): int(count) for book_id, count in rows}
    assert len(rows) == len(result), 'グループの重複'
    assert result == expected, name
    canonical = ''.join(f'{key},{result[key]}\n' for key in sorted(result))
    print(name, 'groups=', len(result), 'sum=', sum(result.values()),
          'sha256=', hashlib.sha256(canonical.encode()).hexdigest())
print('両方式とも、全200万件を独立に数えた本ごとの件数と一致')
print('記録のない本:', 1000000 - len(expected))

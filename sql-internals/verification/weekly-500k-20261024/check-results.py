"""CSVの件数・内容・順序を、実行中の測定コンテナで照合する。"""
import argparse
import csv
import hashlib
import io
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('container')
args = parser.parse_args()

def read(name):
    return subprocess.check_output(['docker', 'exec', args.container, 'cat', '/tmp/' + name + '.csv'])

def digest(data):
    return hashlib.sha256(data).hexdigest()

memory = read('weekly-memory')
external = read('weekly-external')
assert memory == external, 'メモリ内と外部ソートで結果が異なる'
rows = list(csv.reader(io.StringIO(memory.decode())))
assert len(rows) == 500000, len(rows)
previous = None
for book_id, finished_at in rows:
    assert '2026-09-14 00:00:00' <= finished_at < '2026-09-21 00:00:00'
    current = (finished_at, int(book_id))
    if previous is not None:
        assert previous[0] > current[0] or (previous[0] == current[0] and previous[1] <= current[1])
    previous = current
print('sort: 500000 records, date range and order OK; memory == external, sha256=' + digest(memory))
first20 = b'\n'.join(memory.splitlines()[:20]) + b'\n'
assert read('weekly-topn') == read('weekly-index') == first20
print('limit: full sort first 20 == top-N heapsort == Index Only Scan, sha256=' + digest(first20))

baseline = None
for method in ['nested', 'hash', 'merge', 'hash64']:
    # ソート済みの全行で比べ、重複レコードも残す。
    lines = sorted(read('ch07-' + method).splitlines())
    assert len(lines) == 500000, (method, len(lines))
    if baseline is None:
        baseline = lines
    else:
        assert baseline == lines, method
    print('join ' + method + ': 500000 records, same multiset, sha256=' + digest(b'\n'.join(lines)))

baseline = None
for method in ['hash', 'group']:
    rows = list(csv.reader(io.StringIO(read('ch08-' + method).decode())))
    counts = {int(book_id): int(count) for book_id, count in rows}
    assert len(rows) == len(counts) == 736097, (method, len(rows), len(counts))
    assert sum(counts.values()) == 2000000
    if baseline is None:
        baseline = counts
    else:
        assert baseline == counts
    canonical = '\n'.join(f'{key},{value}' for key, value in sorted(counts.items())).encode()
    print('aggregate ' + method + ': 736097 groups, total 2000000, identical counts, sha256=' + digest(canonical))

query = """SELECT count(*) FROM (
  SELECT book_id, count(*) AS actual_count FROM reading_records GROUP BY book_id
) actual FULL JOIN (
  SELECT ((floor(power(1 + u * (power(1000001::float8, 0.2) - 1), 5))::bigint
            * 386413) % 1000000) + 1 AS book_id, count(*) AS original_count
  FROM (SELECT n * 0.6180339887498949::float8
               - floor(n * 0.6180339887498949::float8) AS u
        FROM generate_series(1, 2000000) AS n) generated
  GROUP BY 1
) original USING (book_id) WHERE actual_count IS DISTINCT FROM original_count;"""
diff = subprocess.check_output(['docker', 'exec', args.container, 'psql', '-X', '-A', '-t', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'reading_map', '-c', query]).strip()
assert diff == b'0', diff
print('book distribution: all book IDs and counts match the original generator')
print('PASS')

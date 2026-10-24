"""二つのpsql接続で本42を読み書きし、レコードに付いたxmin・xmaxとBのトランザクション番号を記録する（Read Committedのみ）。"""
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
CONTAINER = 'claude-pg-ch11-xmin'
MARKER = '__CH11_END__'


class Session:
    def __init__(self, name):
        self.name = name
        self.process = subprocess.Popen(['docker', 'exec', '-i', CONTAINER, 'psql', '-X', '-U', 'postgres', '-d', 'reading_map', '-v', 'ON_ERROR_STOP=1', '-P', 'pager=off'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)

    def run(self, sql):
        print(f'\n--- 接続{self.name} ---\n{sql}', flush=True)
        self.process.stdin.write(sql + f'\n\\echo {MARKER}\n')
        self.process.stdin.flush()
        output = []
        while True:
            line = self.process.stdout.readline()
            if not line:
                raise RuntimeError(f'接続{self.name}が予期せず終了')
            if line.strip() == MARKER:
                break
            output.append(line)
        result = ''.join(output)
        print(result, end='', flush=True)
        return result

    def close(self):
        self.process.stdin.close()
        self.process.wait(timeout=10)
        assert self.process.returncode == 0


def row(output):
    """1行の結果から、区切り線の次の行を列のリストで返す。"""
    lines = output.splitlines()
    index = next(i for i, line in enumerate(lines) if line.startswith('---'))
    return [cell.strip() for cell in lines[index + 1].split('|')]


A = Session('A')
B = Session('B')
query = 'SELECT id, title, ctid, xmin, xmax FROM mvcc_books WHERE id = 42;'
try:
    A.run("CREATE TABLE mvcc_books (id integer PRIMARY KEY, title text NOT NULL) WITH (autovacuum_enabled = false);\nINSERT INTO mvcc_books VALUES (42, '星の本');")
    first = row(A.run(query))
    assert first[1] == '星の本' and first[2] == '(0,1)' and first[4] == '0'
    insert_xid = first[3]

    B.run("BEGIN;\nUPDATE mvcc_books SET title = '新しい星の本' WHERE id = 42;")
    b_xid = row(B.run('SELECT pg_current_xact_id();'))[0]
    own = row(B.run(query))
    assert own[1] == '新しい星の本' and own[2] == '(0,2)' and own[3] == b_xid and own[4] == '0'

    pending = row(A.run(query))
    assert pending[1] == '星の本' and pending[2] == '(0,1)' and pending[3] == insert_xid and pending[4] == b_xid

    B.run('COMMIT;')
    after = row(A.run(query))
    assert after[1] == '新しい星の本' and after[2] == '(0,2)' and after[3] == b_xid and after[4] == '0'

    A.run('DROP TABLE mvcc_books;')
    print(f'\nPASS: 元のレコード(0,1)のxmin={insert_xid}、BのCOMMIT前にAから見たxmax={b_xid}（Bの番号）、新しいレコード(0,2)のxmin={b_xid}を確認', flush=True)
finally:
    A.close()
    B.close()

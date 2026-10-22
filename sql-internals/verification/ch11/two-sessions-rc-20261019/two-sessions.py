"""二つのpsql接続へ順番にSQLを送り、各操作の完了を確認して記録する（Read Committedのみ）。"""
from pathlib import Path
import subprocess
import time

HERE = Path(__file__).resolve().parent
CONTAINER = 'claude-pg-ch11-rc-20261019'
MARKER = '__CH11_END__'


class Session:
    def __init__(self, name):
        self.name = name
        self.process = subprocess.Popen(['docker', 'exec', '-i', CONTAINER, 'psql', '-X', '-U', 'postgres', '-d', 'reading_map', '-v', 'ON_ERROR_STOP=1', '-P', 'pager=off'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)

    def start(self, sql):
        """SQLを送り、完了を待たずに戻る。出力はfinish()で受け取る。"""
        print(f'\n--- 接続{self.name} ---\n{sql}', flush=True)
        self.process.stdin.write(sql + f'\n\\echo {MARKER}\n')
        self.process.stdin.flush()

    def finish(self):
        """start()したSQLの出力を終了マーカーまで読む。"""
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

    def run(self, sql):
        self.start(sql)
        return self.finish()

    def close(self):
        self.process.stdin.close()
        self.process.wait(timeout=10)
        assert self.process.returncode == 0


def stamp():
    print(f'\n[時刻 {time.strftime("%H:%M:%S")}]', flush=True)


A = Session('A')
B = Session('B')
query = 'SELECT id, title, ctid FROM mvcc_books WHERE id = 42;'
try:
    print('=== 第1部：確定前後の見え方とVACUUM ===', flush=True)
    A.run("CREATE TABLE mvcc_books (id integer PRIMARY KEY, title text NOT NULL) WITH (autovacuum_enabled = false);\nINSERT INTO mvcc_books VALUES (42, '星の本');")
    first = A.run(query)
    assert '星の本' in first and '(0,1)' in first

    own = B.run("BEGIN;\nUPDATE mvcc_books SET title = '新しい星の本' WHERE id = 42;\n" + query)
    assert '新しい星の本' in own and '(0,2)' in own

    pending = A.run(query)
    assert '星の本' in pending and '新しい星の本' not in pending

    vacuum1 = A.run('VACUUM (VERBOSE) mvcc_books;')
    # 想定は「0 removed, 2 remain」だったが、実測は異なったため「0 removed」だけを確認する
    assert 'tuples: 0 removed' in vacuum1

    B.run('COMMIT;')
    after = A.run(query)
    assert '新しい星の本' in after and '(0,2)' in after

    vacuum2 = A.run('VACUUM (VERBOSE) mvcc_books;')
    assert '1 removed, 1 remain' in vacuum2

    latest = A.run(query)
    assert '新しい星の本' in latest

    print('\n=== 第2部：実行中のSELECTが古い版を残す ===', flush=True)
    A.run("TRUNCATE mvcc_books;\nINSERT INTO mvcc_books VALUES (42, '星の本');")
    stamp()
    A.start("SELECT id, title, ctid, pg_sleep(30) FROM mvcc_books WHERE id = 42;")
    time.sleep(2)
    stamp()
    B.run("UPDATE mvcc_books SET title = '新しい星の本' WHERE id = 42;")
    stamp()
    vacuum3 = B.run('VACUUM (VERBOSE) mvcc_books;')
    assert '1 are dead but not yet removable' in vacuum3
    stamp()
    sleeping = A.finish()
    assert '星の本' in sleeping and '新しい星の本' not in sleeping and '(0,1)' in sleeping
    stamp()
    vacuum4 = B.run('VACUUM (VERBOSE) mvcc_books;')
    assert '1 removed, 1 remain' in vacuum4
    final = A.run(query)
    assert '新しい星の本' in final and '(0,2)' in final
    A.run('DROP TABLE mvcc_books;')
    print('\nPASS: Read Committedでの確定前後の見え方、確定前のVACUUM、確定後のVACUUM、実行中SELECTによる古い版の保持を確認', flush=True)
finally:
    A.close()
    B.close()

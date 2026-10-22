"""二つのpsql接続へ順番にSQLを送り、各操作の完了を確認して記録する。"""
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
CONTAINER = 'codex-pg-ch10-20261004'
class Session:
    def __init__(self, name):
        self.name = name
        self.process = subprocess.Popen(['docker','exec','-i',CONTAINER,'psql','-X','-U','postgres','-d','reading_map','-v','ON_ERROR_STOP=1','-P','pager=off'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
    def run(self, sql):
        print(f'\n--- 接続{self.name} ---\n{sql}',flush=True)
        self.process.stdin.write(sql + '\n\\echo __CH10_END__\n')
        self.process.stdin.flush()
        output=[]
        while True:
            line=self.process.stdout.readline()
            if not line:
                raise RuntimeError(f'接続{self.name}が予期せず終了')
            if line.strip()=='__CH10_END__':
                break
            output.append(line)
        result=''.join(output)
        print(result,end='',flush=True)
        return result
    def close(self):
        self.process.stdin.close()
        self.process.wait(timeout=10)
        assert self.process.returncode==0

A=Session('A')
B=Session('B')
query='SELECT id, title, ctid FROM mvcc_books WHERE id = 42;'
try:
    A.run("CREATE TABLE mvcc_books (id integer PRIMARY KEY, title text NOT NULL) WITH (autovacuum_enabled = false);\nINSERT INTO mvcc_books VALUES (42, '星の本');")
    for level in ['READ COMMITTED','REPEATABLE READ']:
        print(f'\n=== {level} ===',flush=True)
        if level=='REPEATABLE READ':
            A.run("TRUNCATE mvcc_books;\nINSERT INTO mvcc_books VALUES (42, '星の本');")
        A.run(f'BEGIN ISOLATION LEVEL {level};')
        before=A.run(query)
        assert '星の本' in before and '新しい星の本' not in before
        own=B.run("BEGIN;\nUPDATE mvcc_books SET title = '新しい星の本' WHERE id = 42;\n"+query)
        assert '新しい星の本' in own
        pending=A.run(query)
        assert '新しい星の本' not in pending
        B.run('COMMIT;')
        after=A.run(query)
        assert ('新しい星の本' in after)==(level=='READ COMMITTED')
        if level=='REPEATABLE READ':
            print('\n=== 古い版がまだ必要な間のVACUUM ===',flush=True)
            B.run('VACUUM (VERBOSE) mvcc_books;')
            retained=A.run(query)
            assert '星の本' in retained and '新しい星の本' not in retained
        A.run('COMMIT;')
        latest=A.run(query)
        assert '新しい星の本' in latest
    B.run('VACUUM (VERBOSE) mvcc_books;')
    print('\n=== BEGINだけではRepeatable Readの基準は固定されない ===',flush=True)
    A.run("TRUNCATE mvcc_books;\nINSERT INTO mvcc_books VALUES (42, '星の本');\nBEGIN ISOLATION LEVEL REPEATABLE READ;")
    B.run("BEGIN;\nUPDATE mvcc_books SET title = '新しい星の本' WHERE id = 42;\nCOMMIT;")
    first=A.run(query)
    assert '新しい星の本' in first
    A.run('COMMIT;')
    print('\n=== ROLLBACKの確認 ===',flush=True)
    B.run("BEGIN;\nUPDATE mvcc_books SET title = '取り消す題名' WHERE id = 42;")
    assert '取り消す題名' in B.run(query)
    B.run('ROLLBACK;')
    assert '新しい星の本' in A.run(query)
    print('\nPASS: RC・RRの4時点、未確定の自分の版、古い版の保持、BEGINと最初のSELECTの違い、ROLLBACKを確認',flush=True)
finally:
    A.close()
    B.close()

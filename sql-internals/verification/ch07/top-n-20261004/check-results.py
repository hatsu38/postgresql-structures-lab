"""全件ソートの先頭20件・top-N・Indexの内容と順序を照合する。"""
import csv
import hashlib
import io
import subprocess

container = "codex-pg-ch6-20261004"
outputs = {}
for name, expected in [("full", 499998), ("topn", 20), ("index", 20)]:
    data = subprocess.check_output(["docker", "exec", container, "cat", f"/tmp/ch06-{name}.csv"])
    rows = list(csv.reader(io.StringIO(data.decode())))
    assert len(rows) == expected
    previous = None
    for book_id, finished_at in rows:
        assert "2026-09-14 00:00:00" <= finished_at < "2026-09-21 00:00:00"
        current = (finished_at, int(book_id))
        if previous is not None:
            assert previous[0] > current[0] or (previous[0] == current[0] and previous[1] <= current[1])
        previous = current
    outputs[name] = data
    print(f"{name}: rows={len(rows)}, order=OK, date_range=OK, sha256={hashlib.sha256(data).hexdigest()}")
    print(f"first={rows[0]}, last={rows[-1]}")
first_twenty = b"".join(outputs["full"].splitlines(keepends=True)[:20])
assert first_twenty == outputs["topn"] == outputs["index"]
print("Full sort first 20 rows, top-N, and Index outputs are byte-for-byte identical.")

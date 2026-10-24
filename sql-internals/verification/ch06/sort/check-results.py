"""二つの実行結果が、件数・内容・順序まで一致することを確認する。"""
import csv
import hashlib
import io
import subprocess

container = "codex-pg-ch5"
outputs = {}
for name in ["memory", "external"]:
    data = subprocess.check_output(["docker", "exec", container, "cat", f"/tmp/ch05-{name}.csv"])
    rows = list(csv.reader(io.StringIO(data.decode())))
    assert len(rows) == 499998, len(rows)
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
assert outputs["memory"] == outputs["external"]
print("Two outputs are byte-for-byte identical, including order and duplicates.")

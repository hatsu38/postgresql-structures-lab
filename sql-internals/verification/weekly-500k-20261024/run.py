"""空の専用コンテナで再測定する。採取済みログは上書きしない。"""
import argparse
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('output', type=Path, help='新しく作る出力ディレクトリ')
args = parser.parse_args()
source = Path(__file__).resolve().parent
args.output.mkdir(parents=True, exist_ok=False)
container = f'pg-weekly-500k-{os.getpid()}'
image = 'postgres@sha256:86c951e05bf56c93d95d397747fb8820ac76cc3bedb78f43abd83eedbe3666ae'
subprocess.run(['docker', 'run', '--detach', '--rm', '--name', container,
                '-e', 'POSTGRES_PASSWORD=weekly-local', '-e', 'POSTGRES_DB=reading_map',
                image, '-c', 'autovacuum=off'], check=True)
try:
    # -hでTCPを指定し、初期化中の一時サーバー（Unixソケットのみ）を待機対象から外す。
    for _ in range(150):
        ready = subprocess.run(['docker', 'exec', container, 'pg_isready', '-h', '127.0.0.1',
                                '-U', 'postgres', '-d', 'reading_map'], capture_output=True)
        if ready.returncode == 0:
            break
        time.sleep(0.2)
    else:
        raise RuntimeError('PostgreSQLの起動待ちがタイムアウトした')
    for step in ['setup', 'conditions', 'ch05', 'ch06', 'trace', 'ch07', 'ch08', 'ch09', 'ch10', 'ch11']:
        print(step, flush=True)
        with (source / (step + '.sql')).open('rb') as src, (args.output / (step + '.log')).open('wb') as dst:
            subprocess.run(['docker', 'exec', '-i', container, 'psql', '-X', '-a',
                            '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'reading_map'],
                           stdin=src, stdout=dst, stderr=subprocess.STDOUT, check=True)
    with (args.output / 'check-results.log').open('wb') as dst:
        subprocess.run(['python3', str(source / 'check-results.py'), container],
                       stdout=dst, stderr=subprocess.STDOUT, check=True)
    print('PASS:', args.output, flush=True)
finally:
    subprocess.run(['docker', 'stop', container], check=True)

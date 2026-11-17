#!/usr/bin/env python3
"""Differential builtin tests; run after scoreboard bootstrap.
GOOSE_HOME must be writable by the reference compiler.
"""
import argparse
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--goose', required=True)
p.add_argument('--sh', default=str(ROOT / 'build/scoreboard/sh2'))
a = p.parse_args()


def run(args):
    return subprocess.run(list(map(str, args)), capture_output=True, timeout=60, cwd=ROOT)


with tempfile.TemporaryDirectory(prefix='goose-builtins-') as tmp:
    tmp = Path(tmp)
    positives = sorted((ROOT / 'selfhost/tests').glob('builtins_*.goose'))
    for source in positives:
        native = run([a.goose, source])
        assert native.returncode == 0, native.stderr.decode()
        c, exe = tmp / 'test.c', tmp / 'test'
        emitted = run([a.sh, '-o', c, source])
        assert emitted.returncode == 0, emitted.stderr.decode()
        built = run(['gcc', '-O2', c, '-o', exe, '-lm', '-lpthread'])
        assert built.returncode == 0, built.stderr.decode()
        actual = run([exe])
        assert (actual.returncode, actual.stdout) == (native.returncode, native.stdout), (source, actual)
        print(source.name + ': reference output matches')
    negatives = {
        'type_arguments': 'var a: i64[>..] = []; print(check_length<i64>(a, 1));',
        'pool_shrink': 'reusable var a: i64[>..] = [1,2]; a.pop_n(1);',
        'foreign_index': 'var a=[1,2]; var b=[3,4]; print(a.index_of(b[0]));',
        'count_type': 'var a: i64[>..] = []; print(a.check_length(true));',
        'message_type': 'var a: i64[>..] = []; let s="oops"; print(a.check_length(1,s));',
    }
    for name, body in negatives.items():
        source = tmp / (name + '.goose')
        source.write_text('fn main() { ' + body + ' }\n')
        native = run([a.goose, '--check', source])
        actual = run([a.sh, '--check', source])
        assert native.returncode != 0 and actual.returncode == 1, (name, native, actual)
        print(name + ': rejected by both compilers')

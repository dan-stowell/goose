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
        'merged_pool_shrink': 'var a: i64[>..]=[1]; reusable var p: i64[>..]=[2]; var r: i64[>..]& = if false { a } else { p }; r.clear();',
        'slice_missing_default': 'var x=1; reusable[] var a: i64&[>..]=[]; a.alloc_slice(1);',
        'slice_foreign_root': 'reusable[] var a: i64[>..]=[]; var b: i64[>..]=[1]; a.free_slice(b[..]);',
        'pool_optional': 'reusable var p: i64[>..]=[1]; var r: i64[>..]&?=p; if r { r.alloc_index(2); }',
        'pool_rebind_kind': 'reusable var p: i64[>..]=[1]; reusable[] var q: i64[>..]=[]; var r: i64[>..]&=p; r .= q;',
        'pool_rebind_plain': 'reusable var p: i64[>..]=[1]; var q: i64[>..]=[]; var r: i64[>..]&=p; r .= q;',
        'not_pool': 'var a: i64[>..]=[1]; a.free(0);',
        'slice_pool_free': 'reusable[] var a: i64[>..]=[1]; a.free(0);',
        'pool_shrink': 'reusable var a: i64[>..] = [1,2]; a.pop_n(1);',
        'byteview_write': 'var a=[1,2]; let b=bytes_of(a); b[0]=0;',
        'byteview_growshrink_store': 'var a: i64[>..<]=[1]; var boxes: (const u8[:])[>..]=[]; boxes.push(bytes_of(a));',
        'byteview_merged': 'var a: i64[>..]=[1]; var b: i64[>..]=[2]; let v=bytes_of(if true { a[..] } else { b[..] }); b.clear(); print(v);',
        'byteview_loop': 'var a: i64[>..]=[1,2]; let b=bytes_of(a); for i in 2 { print(b); a.clear(); }',
        'byteview_capture': 'var a: i64[>..]=[1,2]; let b=bytes_of(a); fn read() { print(b); } a.clear(); read();',
        'byteview_shrink': 'var a: i64[>..]=[1,2]; let b=bytes_of(a); a.clear(); print(b);',
        'byteview_references': 'var x=1; var a: i64&[1]=[x]; print(bytes_of(a));',
        'move_readonly': 'let a="abc"; a.move_from("def");',
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

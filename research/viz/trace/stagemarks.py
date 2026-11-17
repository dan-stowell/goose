#!/usr/bin/env python3
"""Find the stage functions in C written by the self-hosted compiler and
make a traceable copy of it.

The self-hosted emitter names every function gg_function_N, so the stages
are found by shape, from compile_command in selfhost/main.goose:

    load_program(ctx, path, "stdlib"); register_declarations(ctx);
    check_program(ctx); generate_c(ctx); write_file(output, ctx.c_final)

The first call after a "stdlib" literal followed by gs_os_write_file (octal-escaped in the C) is
load_program; the next three are register_declarations, check_program and
generate_c. In load_program the first call is load_file and the second
parse; in load_file the call after gs_os_read_file is lex.

Usage: stagemarks.py IN.c OUT.c   writes OUT.c with those functions marked
noinline (gcc -O2 inlines three of them; the extra calls cost nothing
measurable) and prints the --marks= value for bytemove.
"""
import re, sys

src = open(sys.argv[1]).read()
STDLIB = r'\163\164\144\154\151\142'

def body(name):
    m = re.search(r'^static [^\n;]*\b%s\([^\n]*\{\n' % re.escape(name), src, re.M)
    if not m:
        sys.exit('no definition of %s' % name)
    end = src.index('\n}\n', m.end())
    return src[m.end():end]

def calls(text):
    return re.findall(r'\b(gg_function_\d+|gs_os_\w+)\(', text)

# The program can hold several copies of the pipeline (one per caller
# specialization); mark every copy.
stages = []
for m in re.finditer(re.escape(STDLIB), src):
    after = calls(src[m.start():m.start() + 4000])
    if len(after) < 4 or 'gs_os_write_file' not in after[:6]:
        continue
    load_program, register, check, generate = after[:4]
    lp = [c for c in calls(body(load_program)) if c.startswith('gg_function_')]
    load_file, parse = lp[0], lp[1]
    lf = calls(body(load_file))
    lex = [c for c in lf[lf.index('gs_os_read_file') + 1:] if c.startswith('gg_function_')][0]
    stages += [(lex, 'lex', 'e'), (parse, 'parse', 'e'), (load_program, 'parse', 's'),
               (register, 'check', 's'), (check, 'check', 's'), (generate, 'emit', 's')]
stages.append(('gs_os_write_file', 'write', 's'))
out = src
for fn, _, _ in stages:
    out = re.sub(r'^static (?!__attribute__)([^\n;(]*\b%s\()' % fn,
                 r'static __attribute__((noinline)) \1', out, flags=re.M)
open(sys.argv[2], 'w').write(out)
print(','.join('%s=%s:%s' % s for s in stages))

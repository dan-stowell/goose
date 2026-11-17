#!/usr/bin/env python3
"""Reduce a bytemove trace directory to the compact JSON the pictures use.

usage: reduce.py goose TRACE_DIR OUT_C NAME OUT.json CONTEXT.goose  (the self-hosted compiler)
       reduce.py cpp   TRACE_DIR OUT_C NAME OUT.json   (the C++ compiler; also gcc's cc1)

CONTEXT.goose is the traced compiler's selfhost/context.goose: the order of
its owned_* tables in run_compilation is the order of their data stacks.

OUT_C is the C file the traced run wrote (its size finds the self-hosted
compiler's c_final data stack, which anchors the other tables). Plain
Python, no numpy: the samples are reduced per 64 KB chunk.
"""
import json, os, re, struct, sys
from array import array
from bisect import bisect_right

kind, tdir, out_c, name, out_json = sys.argv[1:6]
XBINS, YBINS = 720, 72
LEVELS = ['L1', 'L2', 'L3', 'MEM']

# ---------------------------------------------------------------- events
events = [l.rstrip('\n').split('\t') for l in open(os.path.join(tdir, 'events.tsv'))]
stage_ev, mmaps, startup, brks, dumps, thread_sp = [], [], [], [], [], {}
stage_totals, totals, sample_rate = {}, {}, 64
for e in events:
    t = e[0]
    if t == 'config': sample_rate = int(e[2])
    elif t == 'stage': stage_ev.append((e[1], int(e[2]), int(e[3]), int(e[4])))
    elif t == 'mmap': mmaps.append((int(e[1], 16), int(e[2]), e[3], e[5] if len(e) > 5 else '-'))
    elif t == 'startup': startup.append((int(e[1], 16), int(e[2]), e[3], e[5] if len(e) > 5 else '-'))
    elif t == 'brk': brks.append((int(e[1], 16), int(e[2])))
    elif t == 'dump': dumps.append((int(e[1]), e[2]))
    elif t == 'thread_sp': thread_sp[int(e[1])] = (int(e[2], 16), int(e[3], 16))
    elif t == 'stage_total':
        v = [int(x) for x in e[2:]]
        stage_totals[e[1]] = {'acc': [v[2 * l] + v[2 * l + 1] for l in range(4)],
                              'reads': [v[2 * l] for l in range(4)],
                              'writes': [v[2 * l + 1] for l in range(4)], 'wb_mem': v[8]}
    elif t == 'totals':
        totals = {e[i]: int(e[i + 1]) for i in range(1, len(e) - 1, 2)}

# cc1 is stripped: no stage marks, the whole run is one stage.
def rn(st): return 'cc1 -O2' if kind == 'gcc' and st == 'start' else st
stage_ev = [(rn(a), b, c, d) for a, b, c, d in stage_ev]
stage_totals = {rn(k): v for k, v in stage_totals.items()}

# ---------------------------------------------------------------- regions
# A region is a list of (start, end, member) intervals; classify() maps an
# address to (region index, member index).
regions = []          # [{name, members:[...], ivals:[(lo,hi,member)]}]
def region(rname, note=''):
    for i, r in enumerate(regions):
        if r['name'] == rname: return i
    regions.append({'name': rname, 'note': note, 'members': [], 'ivals': []})
    return len(regions) - 1
def add(rname, member, lo, hi, note=''):
    r = regions[region(rname, note)]
    if member not in r['members']: r['members'].append(member)
    r['ivals'].append((lo, hi, r['members'].index(member)))

out_len = os.path.getsize(out_c)
GOOSE_TABLES = []
if kind == 'goose':
    ctx_src = open(sys.argv[6]).read()
    body = ctx_src[ctx_src.index('fn run_compilation'):]
    body = body[:body.index('var ctx')]
    GOOSE_TABLES = re.findall(r'var owned_(\w+)\s*:', body)
GROUPS = [('source text', ['text_storage', 'sources']),
          ('tokens', ['tokens']),
          ('nodes + edges', ['nodes', 'edges', 'declarations']),
          ('types + symbols', ['types', 'fielddefs', 'scopes', 'symbols']),
          ('checker tables', ['function_instances', 'checked_calls', 'shrinks', 'specializations']),
          ('emitter tables', ['global_order', 'symbol_slots', 'c_type_state', 'function_slots',
                              'return_locals', 'c_controls']),
          ('C text out', ['c_output', 'c_declarations', 'c_final', 'c_arguments', 'c_specs'])]
def group_of(t):
    for g, ms in GROUPS:
        if t in ms: return g
    if 'symbol' in t or 'scope' in t or 'type' in t or 'field' in t: return 'types + symbols'
    if t.startswith('c_') or 'local' in t or 'slot' in t or 'stack' in t: return 'emitter tables'
    return 'checker tables'

NOTES = {'source text': 'text_storage (the files read, plus interned strings) and sources',
         'tokens': 'Token[] from the lexer',
         'nodes + edges': 'the tree: Node[], Edge[] and the declaration list',
         'types + symbols': 'Type[], Field[], Scope[], Symbol[] (and the symbol hash index, once it exists)',
         'checker tables': 'specializations, checked calls, function instances, shrinks, call graph',
         'emitter tables': 'slots, type state, global order, control stack',
         'C text out': 'C being written: c_output, c_declarations, then c_final',
         'temporaries': 'every other data stack: the values functions build and drop',
         'C stack': 'the machine stack (frames, spills, small locals)',
         'binary, libc, heap': 'the program image, its globals (gg_stacks), libc, malloc'}
RESERVE = 268435456 + 65536

if kind == 'goose':
    # The stack table at the last dump (taken entering 'write') still holds
    # every table's top; c_final is the stack whose top is the output size.
    last = max(d[0] for d in dumps)
    raw = open(os.path.join(tdir, 'dump-%d.bin' % last), 'rb').read()
    stacks = [struct.unpack_from('<QQQ', raw, 24 * i) for i in range(len(raw) // 24)]
    cfinal = [i for i, s in enumerate(stacks) if s[0] and s[1] == out_len]
    assert len(cfinal) == 1, cfinal
    B = cfinal[0] - GOOSE_TABLES.index('c_final')
    assert stacks[B + GOOSE_TABLES.index('sources')][1] > 0
    order = [g for g, _ in GROUPS]
    for t in sorted(GOOSE_TABLES, key=lambda t: order.index(group_of(t))):
        s = stacks[B + GOOSE_TABLES.index(t)]
        add(group_of(t), t, s[0], s[0] + RESERVE, NOTES[group_of(t)])
    for i, s in enumerate(stacks):
        if s[0] and not (B <= i < B + len(GOOSE_TABLES)):
            add('temporaries', 'stack %d' % i, s[0], s[0] + RESERVE, NOTES['temporaries'])
    lo, hi = thread_sp[1]
    add('C stack', 'main thread', lo - (1 << 20), hi + 65536, NOTES['C stack'])
else:
    for tid, (lo, hi) in sorted(thread_sp.items()):
        add('C stacks', 'thread %d' % tid, lo - (1 << 20), hi + 65536,
            'the machine stacks of each thread')
    # File-backed segments, and the anonymous segment right after one (its
    # .bss), are the image; every other anonymous mapping and the brk range
    # is malloc's (glibc's main and per-thread arenas).
    segs = sorted(startup + mmaps)
    file_ends = set(a + l for a, l, perm, fn in segs if fn != '-')
    for a, l, perm, fn in segs:
        if fn != '-' or a in file_ends:
            add('binary + libraries', 'image', a, a + l,
                'the compiler binary, libstdc++, libc: code, tables, globals')
    if brks:
        b0 = brks[0][0]; bmax = max(b[0] + b[1] for b in brks)
        add('heap', 'brk heap', b0, bmax, 'malloc: brk heap and arena mmaps (AST, types, strings, vectors)')
    for a, l, perm, fn in mmaps:
        if fn == '-' and a not in file_ends:
            add('heap', 'mmap', a, a + l, '')
OTHER = 'binary, libc, heap' if kind == 'goose' else 'other'
region(OTHER, NOTES.get(OTHER, 'everything else'))

flat = []
for ri, r in enumerate(regions):
    for lo, hi, mi in r['ivals']:
        flat.append((lo, hi, ri, mi))
# Earlier entries win (stacks before heap); keep a sorted list for lookup.
flat_sorted = sorted(flat)
starts = [f[0] for f in flat_sorted]
def classify(addr):
    i = bisect_right(starts, addr) - 1
    best = None
    # walk back over a few overlapping intervals; prefer the first-added one
    j = i
    while j >= 0 and j > i - 64:
        lo, hi, ri, mi = flat_sorted[j]
        if lo <= addr < hi:
            cand = (flat.index(flat_sorted[j]), ri, mi)
            if best is None or cand < best: best = cand
        j -= 1
    if best is None: return (len(regions) - 1, 0)
    return best[1], best[2]

# ---------------------------------------------------------------- exact totals per chunk
chunk_region = {}
def chunk_of(c):
    if c not in chunk_region: chunk_region[c] = classify(c << 16)
    return chunk_region[c]
reg_stage = [dict() for _ in regions]       # region -> stage -> [L1..MEM accesses]
member_tot = [dict() for _ in regions]      # region -> member -> [L1..MEM]
for line in open(os.path.join(tdir, 'agg.tsv')):
    f = line.split('\t')
    st, chunk = rn(f[0]), int(f[1], 16) >> 16
    v = [int(x) for x in f[2:10]]
    acc = [v[2 * l] + v[2 * l + 1] for l in range(4)]
    ri, mi = chunk_of(chunk)
    d = reg_stage[ri].setdefault(st, [0, 0, 0, 0])
    for l in range(4): d[l] += acc[l]
    mname = regions[ri]['members'][mi] if regions[ri]['members'] else '-'
    d = member_tot[ri].setdefault(mname, [0, 0, 0, 0])
    for l in range(4): d[l] += acc[l]

# ---------------------------------------------------------------- samples -> cells
samples = array('Q')
with open(os.path.join(tdir, 'samples.bin'), 'rb') as fh:
    samples.frombytes(fh.read())
N = len(samples)
# y position: rank of the 64 KB chunk among the chunks this region touched,
# ordered by member then address (so empty reservation never takes room).
touched = [set() for _ in regions]
for s in samples:
    c = (s & 0xFFFFFFFFFFFF) >> 16
    ri, mi = chunk_of(c)
    touched[ri].add((mi, c))
rank = [{} for _ in regions]
for ri in range(len(regions)):
    for k, (mi, c) in enumerate(sorted(touched[ri])):
        rank[ri][c] = k
cells = [dict() for _ in regions]
for idx, s in enumerate(samples):
    a = s & 0xFFFFFFFFFFFF
    c = a >> 16
    ri, _ = chunk_region[c]
    nch = len(rank[ri])
    y = ((rank[ri][c] << 16) | (a & 0xFFFF)) * YBINS // (nch << 16)
    x = idx * XBINS // N
    key = x * YBINS + y
    cell = cells[ri].get(key)
    if cell is None: cell = cells[ri][key] = [0, 0, 0, 0]
    cell[(s >> 48) & 3] += 1

# member boundaries along y, for labels
out_regions = []
for ri, r in enumerate(regions):
    if not touched[ri]: continue
    nch = len(rank[ri])
    bounds = []
    for mi, mname in enumerate(r['members']):
        ks = [rank[ri][c] for (m, c) in touched[ri] if m == mi]
        if ks: bounds.append({'name': mname, 'y0': min(ks) * YBINS / nch, 'y1': (max(ks) + 1) * YBINS / nch,
                              'chunks': len(ks)})
    flatcells = []
    for key in sorted(cells[ri]):
        flatcells += [key // YBINS, key % YBINS] + cells[ri][key]
    members = sorted(([m, v] for m, v in member_tot[ri].items()), key=lambda mv: -sum(mv[1][1:]))
    out_regions.append({'name': r['name'], 'note': r['note'], 'chunks': nch,
                        'bytes_spanned': nch * 65536, 'by_stage': reg_stage[ri],
                        'members': members[:40], 'bounds': bounds if kind == 'goose' else [],
                        'cells': flatcells})
# biggest first for C++ (few regions); fixed order for goose
segs = []
for i, (st, acc, smp, ins) in enumerate(stage_ev):
    end = stage_ev[i + 1][2] if i + 1 < len(stage_ev) else totals.get('samples', N)
    if end > smp: segs.append([st, smp / N, end / N, ins])
json.dump({'name': name, 'kind': kind, 'xbins': XBINS, 'ybins': YBINS, 'sample_rate': sample_rate,
           'samples': N, 'accesses': totals.get('accesses'), 'instructions': totals.get('instructions'),
           'c_bytes_out': out_len, 'stage_segments': segs, 'stage_totals': stage_totals,
           'regions': out_regions}, open(out_json, 'w'), separators=(',', ':'))
print('%s: %d samples, %d regions, %d bytes' % (out_json, N, len(out_regions), os.path.getsize(out_json)))

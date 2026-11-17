import sys, collections, statistics
# min/median/max per (label, name) from emit_bench.sh lines "<label> <name> <secs> s <kb> KB".
d = collections.defaultdict(list)
for line in open(sys.argv[1]):
    f = line.split()
    if len(f) >= 4 and f[3] == 's':
        d[(f[0], f[1])].append(float(f[2]))
    elif f and f[0] in ("bytes", "instr"):
        print(line.strip())
for (label, name), v in d.items():
    v.sort()
    print(f"{label:8} {name:10} min {v[0]:.3f} median {statistics.median(v):.3f} max {v[-1]:.3f} (n={len(v)})")

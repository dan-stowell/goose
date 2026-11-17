#!/usr/bin/env python3
"""The selfhost fixture scoreboard (research/PLAN.md, M1 and the oracle number).

Builds selfhost/ (stage 1 with the C++ compiler, stage 2 with stage 1 and gcc -O2), checks W1's
fixed point (stage 2 and stage 3 C identical), then scores the stage-2 compiler on:

  run     positive fixtures (test/<category>/*.goose with test/expected/<name>.out, the set
          test/run_tests.py builds and runs): emitted C built with gcc -O2 and run; pass when
          exit status and stdout match the blessed output (and expected/<name>.aborts/.stderr).
  reject  error fixtures (test/errors/, test/errors_tc/): pass when the compiler exits 1 and every
          `// error:` marker occurs in its `file:line:col: error:` lines; `rejected` counts exit 1.
  stdlib  stdlib/*.goose: pass when `--check` accepts the module.

Writes selfhost/scoreboard/<board>.txt (the passing names, sorted) unless --check-only, and
build/scoreboard/<board>.tsv (every fixture with its status and first reason line). With
--enforce, exits nonzero when a name in a committed board no longer passes or the fixed point
breaks: the scoreboard never goes down. Usage:

  python3 selfhost/scoreboard.py [--goose build/goose] [-j N] [--enforce] [--update] [--only board]
"""

import argparse
import concurrent.futures as cf
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEST = ROOT / "test"
BOARDS = Path(__file__).resolve().parent / "scoreboard"
NATIVE = {"audio", "gfx", "physics", "ui", "packages"}
SKIP_DIRS = {"errors", "errors_tc", "goose_in_goose", "lsp"}


def run(argv, timeout=60, cwd=None, stdin=None):
    try:
        p = subprocess.run([str(a) for a in argv], capture_output=True, timeout=timeout, cwd=cwd,
                           stdin=stdin if stdin is not None else subprocess.DEVNULL)
        return p.returncode, p.stdout.decode("utf-8", "replace"), p.stderr.decode("utf-8", "replace")
    except subprocess.TimeoutExpired:
        return -999, "", "timeout"


def first_line(text):
    for line in text.splitlines():
        if line.strip():
            return line.strip()[:200]
    return ""


def joined(text):
    return "\n".join(line.rstrip("\r") for line in text.replace("\r\n", "\n").split("\n")).rstrip("\n")


def bootstrap(goose, work):
    """Stage 1 by the C++ compiler, stage 2 by stage 1 + gcc -O2, stage 3 C by stage 2."""
    work.mkdir(parents=True, exist_ok=True)
    main = ROOT / "selfhost" / "main.goose"
    t0 = time.time()
    code, out, err = run([goose, "build", main, "-o", work / "sh1"], timeout=600)
    if code:
        sys.exit(f"stage 1 build failed:\n{out}{err}")
    for stage, exe in ((2, "sh1"), (3, "sh2")):
        code, out, err = run([work / exe, "-o", work / f"sh{stage}.c", main], timeout=600)
        if code:
            sys.exit(f"stage {stage} emission failed:\n{out}{err}")
        if stage == 2:
            code, out, err = run(["gcc", "-O2", "-w", work / "sh2.c", "-o", work / "sh2", "-lm", "-lpthread"],
                                 timeout=600)
            if code:
                sys.exit(f"stage 2 gcc failed:\n{err}")
    fixed = (work / "sh2.c").read_bytes() == (work / "sh3.c").read_bytes()
    return work / "sh2", fixed, time.time() - t0


def positive_fixtures():
    tests = [f for f in sorted(TEST.glob("*/*.goose"))
             if f.parent.name not in SKIP_DIRS and f.name != "lexer_tokens.goose"]
    out = []
    for f in tests:
        if not (TEST / "expected" / f"{f.stem}.out").exists():
            continue
        if re.search(r"^// error: ", f.read_text(encoding="utf-8"), re.MULTILINE):
            continue
        out.append(f)
    return out


def error_fixtures():
    own = [f for f in sorted((ROOT / "selfhost" / "tests").glob("*.goose"))
           if re.search(r"^// error: ", f.read_text(encoding="utf-8"), re.MULTILINE)]
    return sorted((TEST / "errors").glob("*.goose")) + sorted((TEST / "errors_tc").glob("*.goose")) + own


def score_run(sh, f, work):
    name = f.stem
    rel = f.relative_to(ROOT)
    if f.parent.name in NATIVE or f.with_suffix(".build").exists():
        return name, "unsupported", "native module or sidecar"
    d = work / "run" / f.parent.name
    d.mkdir(parents=True, exist_ok=True)
    c, exe = d / f"{name}.c", d / name
    code, out, err = run([sh, "-o", c, rel], timeout=60, cwd=ROOT)
    if code == -999:
        return name, "crash", "selfhost timeout"
    if code:
        reason = first_line(err) or first_line(out)
        status = "reject" if code == 1 else "crash"
        return name, status, re.sub(r"^\S+:\d+:\d+: ", "", reason)
    code, out, err = run(["gcc", "-O2", "-w", c, "-o", exe, "-lm", "-lpthread"], timeout=120)
    if code:
        return name, "cc-error", first_line(re.sub(r"^.*?: ", "", err, flags=re.M))
    exp = TEST / "expected"
    args = (exp / f"{name}.args").read_text().split() if (exp / f"{name}.args").exists() else []
    code, out, err = run([exe, *args], timeout=30, cwd=ROOT)
    aborts = (exp / f"{name}.aborts").exists()
    if code == -999:
        return name, "mismatch", "run timeout"
    if aborts != (code != 0):
        return name, "mismatch", f"exit {code}: {first_line(err)}"
    sf = exp / f"{name}.stderr"
    if sf.exists():
        markers = [m.strip() for m in sf.read_text().splitlines() if m.strip()]
        if any(m not in err for m in markers):
            return name, "mismatch", "stderr markers"
    if joined(out) != joined((exp / f"{name}.out").read_text(encoding="utf-8", errors="replace")):
        return name, "mismatch", "stdout differs"
    return name, "pass", ""


def score_reject(sh, f, work):
    rel = f.relative_to(ROOT)
    markers = re.findall(r"^// error: (.+)$", f.read_text(encoding="utf-8"), re.MULTILINE)
    code, out, err = run([sh, "--check", rel], timeout=60, cwd=ROOT)
    key = f"{f.parent.name}/{f.stem}"
    if code != 1:
        return key, ("crash" if code not in (0, 1) else "accepted"), f"exit {code}: {first_line(err)}"
    diags = "\n".join(m[1] for m in (re.match(r"^\S.*:\d+(?::\d+)?: error: (.*)$", l) for l in err.splitlines()) if m)
    missing = [m for m in markers if m not in diags]
    if not markers or missing:
        return key, "rejected", first_line(diags)
    return key, "pass", ""


def score_stdlib(sh, f, work):
    code, out, err = run([sh, "--check", f.relative_to(ROOT)], timeout=60, cwd=ROOT)
    if code == 0:
        return f.stem, "pass", ""
    return f.stem, ("reject" if code == 1 else "crash"), re.sub(r"^\S+:\d+:\d+: ", "", first_line(err))


BOARD_FNS = {"run": (positive_fixtures, score_run),
             "reject": (error_fixtures, score_reject),
             "stdlib": (lambda: sorted((ROOT / "stdlib").glob("*.goose")), score_stdlib)}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--goose", default=str(ROOT / "build" / "goose"))
    ap.add_argument("--sh", help="score this stage-2 compiler instead of bootstrapping")
    ap.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    ap.add_argument("--work", default=str(ROOT / "build" / "scoreboard"))
    ap.add_argument("--only", choices=sorted(BOARD_FNS), action="append")
    ap.add_argument("--update", action="store_true", help="rewrite selfhost/scoreboard/*.txt")
    ap.add_argument("--enforce", action="store_true", help="fail if a committed pass regressed")
    ap.add_argument("--clusters", type=int, default=12, help="print the N largest failure reasons")
    args = ap.parse_args()
    work = Path(args.work)
    work.mkdir(parents=True, exist_ok=True)
    if args.sh:
        sh, fixed, secs = Path(args.sh).resolve(), None, 0.0
    else:
        sh, fixed, secs = bootstrap(args.goose, work)
        print(f"bootstrap: {secs:.1f} s; W1 fixed point (stage 2 C == stage 3 C): {'yes' if fixed else 'NO'}")
    failed = fixed is False
    for board in args.only or ["run", "reject", "stdlib"]:
        files_fn, score = BOARD_FNS[board]
        files = files_fn()
        t0 = time.time()
        with cf.ThreadPoolExecutor(args.jobs) as ex:
            results = list(ex.map(lambda f: score(sh, f, work), files))
        counts = {}
        for _, status, _ in results:
            counts[status] = counts.get(status, 0) + 1
        passing = sorted(n for n, s, _ in results if s == "pass")
        detail = ", ".join(f"{k} {v}" for k, v in sorted(counts.items(), key=lambda kv: -kv[1]) if k != "pass")
        print(f"{board}: {len(passing)}/{len(files)} pass ({detail}) in {time.time() - t0:.1f} s")
        with open(work / f"{board}.tsv", "w") as fh:
            for n, s, why in results:
                fh.write(f"{n}\t{s}\t{why}\n")
        clusters = {}
        for _, s, why in results:
            if s != "pass":
                key = re.sub(r"\b\d+\b", "_", why)[:90]
                clusters[key] = clusters.get(key, 0) + 1
        for key, n in sorted(clusters.items(), key=lambda kv: -kv[1])[:args.clusters]:
            print(f"  {n:5d}  {key}")
        committed = BOARDS / f"{board}.txt"
        if committed.exists():
            before = set(committed.read_text().split())
            lost = sorted(before - set(passing))
            if lost:
                print(f"  REGRESSED ({len(lost)}): {' '.join(lost[:20])}")
                failed = True
            gained = len(set(passing) - before)
            if gained:
                print(f"  gained {gained} (run with --update to record)")
        if args.update:
            BOARDS.mkdir(exist_ok=True)
            committed.write_text("".join(f"{n}\n" for n in passing))
    if args.enforce and failed:
        sys.exit(1)


if __name__ == "__main__":
    main()

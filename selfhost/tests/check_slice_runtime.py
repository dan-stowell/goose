#!/usr/bin/env python3
"""Compare 500 seeded slice-pool operations with the reference compiler.

Tests the actual embedded C runtime under UBSan, independently of selfhost's
checker/emitter. The C harness supplies the zero defaults normally emitted for
i64 elements. Requires GCC (or compatible --cc) and a writable GOOSE_HOME.
"""
import argparse
import os
from pathlib import Path
import random
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def run(command, *, expected=0):
    result = subprocess.run(list(map(str, command)), capture_output=True, timeout=180)
    if result.returncode != expected:
        raise AssertionError(
            f"{command}: expected status {expected}, got {result.returncode}\n"
            + result.stderr.decode(errors="replace")
        )
    return result


def sources():
    c = [
        "int main(void) { gg_header h; gg_reference p;",
        "gg_stack *st=gg_get_stack(0); h.base=st->base; h.len=0;",
        "p=gg_ref(&h,st); gg_reset_pool(st);",
        *(f"gg_slice s{i}=gg_view(NULL,0);" for i in range(8)),
    ]
    goose = [
        "fn main() { reusable[] var p:i64[>..]=[];",
        *(f"var s{i}:i64[:]=p.alloc_slice(0);" for i in range(8)),
    ]
    rng = random.Random(22)
    live = [False] * 8
    for step in range(500):
        i, n = rng.randrange(8), rng.randrange(15)
        if not live[i]:
            c.append(f"s{i}=gg_pool_slice_alloc(p,{n},8); "
                     f"memset(s{i}.data,0,(size_t)s{i}.len*8);")
            goose.append(f"s{i}=p.alloc_slice({n});")
            live[i] = True
        elif rng.randrange(4) == 0:
            c.append(f"gg_pool_slice_free(p,s{i},8); s{i}=gg_view(NULL,0);")
            goose.append(f"p.free_slice(s{i}); s{i}=p[..0];")
            live[i] = False
        else:
            c.append(f"{{int64_t old=s{i}.len; "
                     f"s{i}=gg_pool_slice_realloc(p,s{i},{n},8); "
                     f"if(s{i}.len>old)memset((int64_t*)s{i}.data+old,0,"
                     f"(size_t)(s{i}.len-old)*8);}}")
            goose.append(f"s{i}=p.realloc_slice(s{i},{n});")
        # Inspect retained/default elements before assigning identifiable data.
        c.append(
            f"{{int64_t sum=0,j;for(j=0;j<s{i}.len;j++)"
            f"sum+=((int64_t*)s{i}.data)[j];"
            'printf("%lld %lld %lld %lld\\n",(long long)h.len,'
            f"(long long)(s{i}.len?((unsigned char*)s{i}.data-h.base)/8:0),"
            f"(long long)s{i}.len,(long long)sum);"
            f"for(j=0;j<s{i}.len;j++)((int64_t*)s{i}.data)[j]={step + 1}+j;}}"
        )
        goose.append(
            f"{{var sum:i64=0;for v in s{i} {{sum+=v;}}"
            f'print(p.len," ",p.range_index(s{i})," ",s{i}.len," ",sum);'
            f"for j in s{i}.len {{s{i}[j]={step + 1}+j;}}}}"
        )
    return "\n".join(c + ["return 0;}"]), "\n".join(goose + ["}"])


BOUNDARIES = r"""
int main(int argc, char **argv) {
    gg_stack *st=gg_get_stack(0);
    gg_header header={st->base,0};
    gg_reference p=gg_ref(&header,st);
    gg_slice s;
    int which=atoi(argv[1]);
    gg_reset_pool(st); s=gg_pool_slice_alloc(p,4,8);
    switch(which) {
    case 0: gg_pool_slice_free(p,gg_view(NULL,0),8); return 0;
    case 1: gg_pool_slice_alloc(p,UINT64_MAX,8); break;
    case 2: gg_pool_slice_alloc(p,GG_RESERVATION/8+1,8); break;
    case 3: gg_pool_slice_free(p,gg_view(st->base+1,1),8); break;
    case 4: gg_pool_slice_free(p,gg_view(st->base+24,2),8); break;
    case 5: gg_pool_slice_free(p,gg_view(st->base,-1),8); break;
    case 6: gg_pool_busy[0]=1; gg_pool_slice_alloc(p,1,8); break;
    case 7: gg_pool_busy[0]=1; gg_pool_slice_realloc(p,s,2,8); break;
    case 8:
        /* Model an exhausted reservation without committing its pages. */
        header.len=GG_RESERVATION/8; st->top=GG_RESERVATION;
        gg_pool_slice_alloc(p,1,8); break;
    case 9: gg_pool_slice_free(p,gg_view(&which,0),8); return 0;
    }
    return 0;
}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--goose", required=True)
    parser.add_argument("--cc", default=os.environ.get("CC", "gcc"))
    args = parser.parse_args()
    # runtime_source() is a raw multiline Goose string, emitted verbatim.
    runtime = (ROOT / "selfhost/runtime.goose").read_text().split(
        'return """', 1
    )[1].split('""";', 1)[0]
    with tempfile.TemporaryDirectory(prefix="goose-slice-runtime-") as directory:
        tmp = Path(directory)
        c, goose = sources()
        source = tmp / "sequence.goose"
        source.write_text(goose)
        c_source, executable = tmp / "sequence.c", tmp / "sequence"
        c_source.write_text(runtime + c)
        flags = ["-O1", "-fsanitize=undefined", "-fno-sanitize-recover=undefined"]
        run([args.cc, *flags, c_source, "-o", executable, "-lm"])
        actual = run([executable])
        native = run([args.goose, source])
        if actual.stderr:
            raise AssertionError(actual.stderr.decode(errors="replace"))
        if actual.stdout != native.stdout:
            actual_lines, native_lines = actual.stdout.splitlines(), native.stdout.splitlines()
            for i in range(max(len(actual_lines), len(native_lines))):
                got, want = actual_lines[i:i + 1], native_lines[i:i + 1]
                if got != want:
                    raise AssertionError(f"operation {i}: runtime {got}, reference {want}")
        print("500 seeded alloc/free/realloc operations match reference; UBSan clean")

        c_source, executable = tmp / "boundaries.c", tmp / "boundaries"
        c_source.write_text(runtime + BOUNDARIES)
        run([args.cc, *flags, c_source, "-o", executable, "-lm"])
        for i in range(10):
            result = run([executable, str(i)], expected=0 if i in (0, 9) else 1)
            # A Goose abort is expected; a sanitizer report is never expected.
            if b"runtime error:" in result.stderr.replace(b"goose runtime error:", b""):
                raise AssertionError(result.stderr.decode(errors="replace"))
        print("10 bounds/busy/empty-slice cases pass; UBSan clean")


if __name__ == "__main__":
    main()

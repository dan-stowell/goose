// Independently written target runtime. This text is emitted verbatim; it
// neither includes nor extracts the bootstrap compiler's runtime.
fn runtime_source() -> const u8[:] {
    return """
    /* Goose-in-Goose experimental C backend. Generated from test/goose_in_goose/. */
    #include <stdint.h>
    #include <stddef.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <math.h>
    #include <limits.h>
    #ifdef _MSC_VER
    #include <malloc.h>
    #endif
    #ifdef _WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #else
    #include <sys/mman.h>
    #include <signal.h>
    #include <sys/stat.h>
    #include <unistd.h>
    #endif
    typedef struct { void *data; int64_t len; } gg_slice;
    typedef struct { unsigned char *base; int64_t len; } gg_header;
    typedef struct { unsigned char *base; size_t top, committed; } gg_stack;
    typedef struct { gg_header *header; gg_stack *stack; } gg_reference;
    #define GG_RESERVATION ((size_t)268435456)
    #define GG_STACK_COUNT 8192
    static gg_stack gg_stacks[GG_STACK_COUNT];
    static int gg_argc;
    static char **gg_argv;
    #ifndef _WIN32
    /* A fault on the guard page past the native stack is reported as an
       overflow, after the program output so far. */
    static char *gg_stack_origin;
    static void gg_on_fault(int sig, siginfo_t *info, void *context) {
        static const char overflow[] = "goose runtime error: native call stack overflow\n";
        char *at = (char *)info->si_addr; (void)sig; (void)context; fflush(stdout);
        if (at <= gg_stack_origin && gg_stack_origin - at < ((ptrdiff_t)1 << 30)) { if (write(2, overflow, sizeof overflow - 1)) {} _exit(1); }
        signal(SIGSEGV, SIG_DFL); raise(SIGSEGV);
    }
    static void gg_guard_stack(void) {
        static char alternate[65536]; stack_t ss; struct sigaction sa; char here;
        gg_stack_origin = &here;
        ss.ss_sp = alternate; ss.ss_size = sizeof alternate; ss.ss_flags = 0; sigaltstack(&ss, NULL);
        memset(&sa, 0, sizeof sa); sa.sa_sigaction = gg_on_fault; sa.sa_flags = SA_ONSTACK | SA_SIGINFO; sigaction(SIGSEGV, &sa, NULL);
    }
    #endif
    static void gg_fail(const char *message) {
        fflush(stdout); fprintf(stderr, "goose runtime error: %s\n", message); exit(1);
    }
    static gg_stack *gg_get_stack(int64_t id) {
        gg_stack *s;
        if (id < 0 || id >= GG_STACK_COUNT) gg_fail("data stack limit exceeded");
        s = &gg_stacks[id];
        if (!s->base) {
    #ifdef _WIN32
            s->base = VirtualAlloc(NULL, GG_RESERVATION + 65536, MEM_RESERVE, PAGE_NOACCESS);
    #else
            s->base = mmap(NULL, GG_RESERVATION + 65536, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
            if (s->base == MAP_FAILED) s->base = NULL;
    #endif
            if (!s->base) gg_fail("cannot reserve data stack");
        }
        return s;
    }
    static void *gg_allocate(gg_stack *s, size_t size) {
        size_t end, committed;
        void *result;
        if (size > GG_RESERVATION - s->top) gg_fail("data stack reservation exceeded");
        result = s->base + s->top; end = s->top + size;
        if (end > s->committed) {
            committed = (end + 65535) & ~(size_t)65535;
    #ifdef _WIN32
            if (!VirtualAlloc(s->base + s->committed, committed - s->committed, MEM_COMMIT, PAGE_READWRITE)) gg_fail("cannot commit data stack");
    #else
            if (mprotect(s->base + s->committed, committed - s->committed, PROT_READ | PROT_WRITE)) gg_fail("cannot commit data stack");
    #endif
            s->committed = committed;
        }
        s->top = end; return result;
    }
    static gg_reference gg_ref(gg_header *h, gg_stack *s) { gg_reference r; r.header=h; r.stack=s; return r; }
    static gg_slice gg_view(void *p, int64_t n) { gg_slice v; v.data=p; v.len=n; return v; }
    static gg_slice gg_sub(gg_slice a, int64_t lo, int64_t hi, size_t element) {
        if (lo < 0 || hi < lo || hi > a.len) gg_fail("slice out of bounds");
        return gg_view((unsigned char *)a.data + (size_t)lo * element, hi - lo);
    }
    static int64_t gg_index(int64_t i, int64_t len) { if ((uint64_t)i >= (uint64_t)len) gg_fail("array index out of bounds"); return i; }
    static void gg_append(gg_reference a, const void *p, int64_t n, size_t element) {
        void *to;
        if (n < 0 || (uint64_t)n > GG_RESERVATION / (element ? element : 1)) gg_fail("invalid array size");
        to=gg_allocate(a.stack, (size_t)n * element);
        if (n && element) memmove(to, p, (size_t)n * element);
        a.header->len += n;
    }
    static void gg_resize(gg_reference a, int64_t n, size_t element, const void *fill) {
        int64_t old=a.header->len, i;
        if (n < 0) gg_fail("resize to a negative length");
        if (n > old) {
            unsigned char *p;
            if (!fill) gg_fail("resize growth requires a fill value");
            if ((uint64_t)(n-old) > GG_RESERVATION / (element ? element : 1)) gg_fail("invalid array size");
            p=gg_allocate(a.stack, (size_t)(n-old)*element);
            for (i=0; i<n-old; i++) if(element) memcpy(p+(size_t)i*element, fill, element);
        } else { a.stack->top = (size_t)(a.header->base-a.stack->base) + (size_t)n*element; }
        a.header->len=n;
    }
    static int64_t gg_check_length(int64_t n, size_t element, const char *message) {
        if (n < 0 || (uint64_t)n > GG_RESERVATION / (element ? element : 1)) gg_fail(message ? message : "invalid array length");
        return n;
    }
    static int64_t gg_range_index(gg_slice a, gg_slice s, size_t element, const char *message) {
        uintptr_t off;
        if (!s.len) return 0;
        off = (uintptr_t)s.data - (uintptr_t)a.data;
        if ((uintptr_t)s.data < (uintptr_t)a.data || (element && off % element) || (element && (int64_t)(off / element) + s.len > a.len)) gg_fail(message ? message : "slice not within this array");
        return element ? (int64_t)(off / element) : 0;
    }
    static void *gg_push_slot(gg_reference a, size_t element) {
        void *to = gg_allocate(a.stack, element); if (element) memset(to, 0, element); a.header->len++; return to;
    }
    /* Relative links: a signed offset from the slot itself, or an offset
       from a pool's base plus one; 0 is null. */
    static int64_t gg_rel_read(void *p, int w, int pool) {
        if (w == 1) return pool ? (int64_t)*(uint8_t *)p : (int64_t)*(int8_t *)p;
        if (w == 2) return pool ? (int64_t)*(uint16_t *)p : (int64_t)*(int16_t *)p;
        if (w == 4) return pool ? (int64_t)*(uint32_t *)p : (int64_t)*(int32_t *)p;
        return *(int64_t *)p;
    }
    static void *gg_rel_load(void *slot, int w, unsigned char *base) {
        int64_t off = gg_rel_read(slot, w, base != NULL);
        if (!off) return NULL;
        return base ? base + off - 1 : (unsigned char *)slot + off;
    }
    static void gg_rel_store(void *slot, int w, unsigned char *base, void *target) {
        int64_t off = 0;
        if (target) {
            off = base ? (int64_t)((unsigned char *)target - base) + 1 : (int64_t)((unsigned char *)target - (unsigned char *)slot);
            if (!off) gg_fail("non-null relative reference encodes as null");
            if (w < 8 && (base ? (off < 0 || (uint64_t)off >> (w * 8)) : (off < -((int64_t)1 << (w * 8 - 1)) || off >= ((int64_t)1 << (w * 8 - 1))))) gg_fail("relative reference offset overflow");
        }
        if (w == 1) *(uint8_t *)slot = (uint8_t)off;
        else if (w == 2) *(uint16_t *)slot = (uint16_t)off;
        else if (w == 4) *(uint32_t *)slot = (uint32_t)off;
        else *(int64_t *)slot = off;
    }
    static void gg_rpop_n(gg_reference a, int64_t k, size_t element) {
        if (k < 0 || k > a.header->len) gg_fail("pop_n count negative or beyond the array's length");
        gg_resize(a, a.header->len - k, element, NULL);
    }
    static void *gg_rpop(gg_reference a, size_t element) {
        if (!a.header->len) gg_fail("pop on empty array");
        return a.header->base + (size_t)(a.header->len - 1) * element;
    }
    /* Packed storage: a variable value is a pointer to its bytes, built by
       appending to a data stack. Stored lengths are 1, 2, 4 or 8 bytes wide,
       or a LEB128 varint (width 0); varint fields are zigzag LEB128. */
    static uint64_t gg_uleb_read(const uint8_t *p) {
        uint64_t v = 0; int shift = 0;
        for (;;) { uint8_t b = *p++; if (shift < 64) v |= (uint64_t)(b & 127) << shift; shift += 7; if (!(b & 128)) return v; }
    }
    static int64_t gg_uleb_size(const uint8_t *p) { int64_t n = 1; while (*p++ & 128) n++; return n; }
    static int64_t gg_zig_read(const uint8_t *p) { uint64_t v = gg_uleb_read(p); return (int64_t)(v >> 1) ^ -(int64_t)(v & 1); }
    static int64_t gg_len_read(const uint8_t *p, int w) {
        if (w == 1) return *p;
        if (w == 2) return *(const uint16_t *)p;
        if (w == 4) return *(const uint32_t *)p;
        if (w == 8) return (int64_t)*(const uint64_t *)p;
        return (int64_t)gg_uleb_read(p);
    }
    static int64_t gg_len_size(const uint8_t *p, int w) { return w ? w : gg_uleb_size(p); }
    static gg_slice gg_frozen_view(uint8_t *p, int w) { return gg_view(p + gg_len_size(p, w), gg_len_read(p, w)); }
    static gg_slice gg_dyn_view(uint8_t *p) { return gg_view(p + 8, *(uint32_t *)(p + 4)); }
    static void gg_dyn_assign(uint8_t *p, gg_slice s, size_t element) {
        if (s.len > (int64_t)*(uint32_t *)p) gg_fail("limited array capacity exceeded");
        if (s.len) memmove(p + 8, s.data, (size_t)s.len * element);
        *(uint32_t *)(p + 4) = (uint32_t)s.len;
    }
    static void gg_push(gg_stack *s, const void *p, size_t n) { void *to = gg_allocate(s, n); if (n) memmove(to, p, n); }
    static void gg_push_uleb(gg_stack *s, uint64_t v) {
        uint8_t b[10]; int n = 0;
        do { b[n] = (uint8_t)(v & 127); v >>= 7; if (v) b[n] |= 128; n++; } while (v);
        gg_push(s, b, (size_t)n);
    }
    static void gg_push_zig(gg_stack *s, int64_t v) { gg_push_uleb(s, ((uint64_t)v << 1) ^ (uint64_t)(v >> 63)); }
    static void gg_push_len(gg_stack *s, int64_t n, int w) {
        uint8_t b1; uint16_t b2; uint32_t b4; uint64_t b8 = (uint64_t)n;
        if (n < 0) gg_fail("invalid array length");
        if (w && w < 8 && (uint64_t)n >> (w * 8)) { fprintf(stderr, "goose runtime error: array length exceeds storage range\n"); exit(1); }
        if (w == 1) { b1 = (uint8_t)n; gg_push(s, &b1, 1); }
        else if (w == 2) { b2 = (uint16_t)n; gg_push(s, &b2, 2); }
        else if (w == 4) { b4 = (uint32_t)n; gg_push(s, &b4, 4); }
        else if (w == 8) gg_push(s, &b8, 8);
        else gg_push_uleb(s, (uint64_t)n);
    }
    static void gg_push_dyn(gg_stack *s, int64_t cap, size_t element) {
        uint32_t h[2]; void *to;
        if (cap < 0 || cap > (int64_t)UINT32_MAX) gg_fail("invalid capacity");
        h[0] = (uint32_t)cap; h[1] = 0; gg_push(s, h, 8);
        to = gg_allocate(s, (size_t)cap * element); if (cap && element) memset(to, 0, (size_t)cap * element);
    }
    /* Limited arrays: a stored length of width w, a capacity and the data. */
    static int64_t gg_lget(void *l, int w) {
        if (w == 1) return *(uint8_t *)l;
        if (w == 2) return *(uint16_t *)l;
        if (w == 4) return *(uint32_t *)l;
        return *(int64_t *)l;
    }
    static void gg_lset(void *l, int w, int64_t n) {
        if (w == 1) *(uint8_t *)l = (uint8_t)n;
        else if (w == 2) *(uint16_t *)l = (uint16_t)n;
        else if (w == 4) *(uint32_t *)l = (uint32_t)n;
        else *(int64_t *)l = n;
    }
    static void *gg_lpush(void *l, int w, int64_t cap, void *data, size_t element) {
        int64_t n = gg_lget(l, w);
        if (n >= cap) gg_fail("limited array capacity exceeded");
        gg_lset(l, w, n + 1); return (unsigned char *)data + (size_t)n * element;
    }
    static void *gg_lpop(void *l, int w, void *data, size_t element) {
        int64_t n = gg_lget(l, w);
        if (!n) gg_fail("pop on empty array");
        gg_lset(l, w, n - 1); return (unsigned char *)data + (size_t)(n - 1) * element;
    }
    static void gg_lpop_n(void *l, int w, int64_t k) {
        int64_t n = gg_lget(l, w);
        if (k < 0 || k > n) gg_fail("pop_n count negative or beyond the array's length");
        gg_lset(l, w, n - k);
    }
    static void gg_lresize(void *l, int w, int64_t cap, void *data, size_t element, int64_t n, const void *fill) {
        int64_t old = gg_lget(l, w), i;
        if (n < 0) gg_fail("resize to a negative length");
        if (n > cap) gg_fail("limited array capacity exceeded");
        if (n > old) { if (!fill) gg_fail("resize growth requires a fill value"); for (i = old; i < n; i++) memcpy((unsigned char *)data + (size_t)i * element, fill, element); }
        gg_lset(l, w, n);
    }
    static void gg_lappend(void *l, int w, int64_t cap, void *data, size_t element, gg_slice s) {
        int64_t n = gg_lget(l, w);
        if (s.len > cap - n) gg_fail("limited array capacity exceeded");
        if (s.len) memmove((unsigned char *)data + (size_t)n * element, s.data, (size_t)s.len * element);
        gg_lset(l, w, n + s.len);
    }
    static int64_t gg_div(int64_t a, int64_t b) { if (!b) gg_fail("division by zero"); if (a==INT64_MIN && b==-1) gg_fail("division overflow"); return a/b; }
    static int64_t gg_mod(int64_t a, int64_t b) {
        int64_t r; if (!b) gg_fail("division by zero"); if (b==-1) return 0;
        r=a%b; if(r<0) return (int64_t)((uint64_t)r + (b<0 ? (uint64_t)0-(uint64_t)b : (uint64_t)b)); return r;
    }
    /* as! from a float: truncate toward zero, then wrap modulo 2^64; NaN and the infinities give 0. */
    static uint64_t gg_float_wrap(double x) {
        double t = trunc(x), m;
        if (t != t || t - t != 0) return 0;
        if (t >= 0) return t < 18446744073709551616.0 ? (uint64_t)t : (uint64_t)fmod(t, 18446744073709551616.0);
        m = fmod(-t, 18446744073709551616.0); return (uint64_t)0 - (uint64_t)m;
    }
    static uint64_t gg_udiv(uint64_t a,uint64_t b) { if(!b)gg_fail("division by zero");return a/b; }
    static uint64_t gg_umod(uint64_t a,uint64_t b) { if(!b)gg_fail("division by zero");return a%b; }
    static int gg_equal(gg_slice a, gg_slice b, size_t element) { return a.len==b.len && (!a.len || !memcmp(a.data,b.data,(size_t)a.len*element)); }
    static void gg_text(gg_reference out, gg_slice v) { gg_append(out,v.data,v.len,1); }
    static void gg_integer(gg_reference out,int64_t n) { char b[32]; int k=snprintf(b,sizeof b,"%lld",(long long)n);gg_append(out,b,k,1); }
    static void gg_unsigned(gg_reference out,uint64_t n) { char b[32]; int k=snprintf(b,sizeof b,"%llu",(unsigned long long)n);gg_append(out,b,k,1); }
    /* The shortest digits that read back to the value of its own type (an f32's
       as an f32), laid out as %g lays them out at a precision of max(15, digits);
       a whole number keeps a .0, and nan and inf are spelled here (spec 3.7). */
    static void gg_float(gg_reference out,double v,int single) {
        char e[48], dig[24], b[64]; int p, n = 0, x, i, k = 0; char *q;
        if (v != v) { gg_append(out,"nan",3,1); return; }
        if (isinf(v)) { if (v > 0) gg_append(out,"inf",3,1); else gg_append(out,"-inf",4,1); return; }
        if (signbit(v)) { b[k++] = '-'; v = -v; }
        if (v == 0) { b[k++] = '0'; b[k++] = '.'; b[k++] = '0'; gg_append(out,b,k,1); return; }
        for (p = 1; p < 17; p++) {
            double r; snprintf(e, sizeof e, "%.*e", p - 1, v); r = strtod(e, NULL);
            if (single ? (float)r == (float)v : r == v) break;
        }
        snprintf(e, sizeof e, "%.*e", p - 1, v);
        for (q = e; *q && *q != 'e'; q++) if (*q >= '0' && *q <= '9') dig[n++] = *q;
        x = atoi(q + 1);
        while (n > 1 && dig[n - 1] == '0') n--;
        if (x < -4 || x >= (n > 15 ? n : 15)) {
            b[k++] = dig[0]; if (n > 1) b[k++] = '.';
            for (i = 1; i < n; i++) b[k++] = dig[i];
            k += snprintf(b + k, sizeof b - k, "e%c%02d", x < 0 ? '-' : '+', x < 0 ? -x : x);
        } else if (x < 0) {
            b[k++] = '0'; b[k++] = '.';
            for (i = -1; i > x; i--) b[k++] = '0';
            for (i = 0; i < n; i++) b[k++] = dig[i];
        } else {
            for (i = 0; i < n || i <= x; i++) { if (i == x + 1) b[k++] = '.'; b[k++] = i < n ? dig[i] : '0'; }
            if (n <= x + 1) { b[k++] = '.'; b[k++] = '0'; }
        }
        gg_append(out,b,k,1);
    }
    static void gg_bool(gg_reference out,uint8_t n) { gg_append(out,n?"true":"false",n?4:5,1); }
    static void gg_write(FILE *file,gg_slice text) { if(text.len && fwrite(text.data,1,(size_t)text.len,file)!=(size_t)text.len)gg_fail("write failed"); }
    static char *gg_cstring(gg_slice path) {
        char *s=malloc((size_t)path.len+1); if(!s)gg_fail("out of memory in file shim");
        if(path.len)memcpy(s,path.data,(size_t)path.len);s[path.len]=0;return s;
    }
    static uint8_t gs_os_read_file(gg_slice path,gg_reference out) {
        char *p=gg_cstring(path);FILE *f=fopen(p,"rb");unsigned char b[16384];size_t n;int ok;free(p);
        if(!f)return 0;while((n=fread(b,1,sizeof b,f))!=0)gg_append(out,b,(int64_t)n,1);ok=!ferror(f);fclose(f);return (uint8_t)ok;
    }
    static uint8_t gs_os_write_file(gg_slice path,gg_slice data) {
        char *p=gg_cstring(path);FILE *f=fopen(p,"wb");int ok;free(p);if(!f)return 0;
        ok=!data.len || fwrite(data.data,1,(size_t)data.len,f)==(size_t)data.len;if(fclose(f))ok=0;return (uint8_t)ok;
    }
    static uint8_t gs_os_file_exists(gg_slice path) {
    #ifndef _WIN32
        struct stat st; char *p=gg_cstring(path); int r=stat(p,&st); free(p); return r==0 && !S_ISDIR(st.st_mode);
    #else
        char*p=gg_cstring(path);FILE*f=fopen(p,"rb");free(p);if(!f)return 0;fclose(f);return 1;
    #endif
    }
    static void gs_os_write_stdout(gg_slice s) { gg_write(stdout,s); }
    static void gs_os_write_stderr(gg_slice s) { gg_write(stderr,s); }
    static void gs_os_flush_stdout(void) { fflush(stdout); }
    static int64_t gs_os_arg_count(void) { return gg_argc; }
    static void gs_os_arg(int64_t i,gg_reference out) { if(i>=0 && i<gg_argc)gg_append(out,gg_argv[i],(int64_t)strlen(gg_argv[i]),1); }
    /* std's externs (stdlib/std.goose, os.goose, math.goose, ffi.goose). */
    #ifndef _WIN32
    #include <sys/stat.h>
    #include <dirent.h>
    #include <time.h>
    #endif
    #define GG_M1(n, f, t) static t n(t x) { return f(x); }
    #define GG_M2(n, f, t) static t n(t x, t y) { return f(x, y); }
    GG_M1(gs_sqrt, sqrt, double) GG_M1(gs_sin, sin, double) GG_M1(gs_cos, cos, double) GG_M1(gs_tan, tan, double)
    GG_M1(gs_asin, asin, double) GG_M1(gs_acos, acos, double) GG_M1(gs_atan, atan, double) GG_M2(gs_atan2, atan2, double)
    GG_M1(gs_exp, exp, double) GG_M1(gs_log, log, double) GG_M1(gs_log2, log2, double) GG_M1(gs_log10, log10, double)
    GG_M2(gs_pow, pow, double) GG_M2(gs_hypot, hypot, double) GG_M1(gs_cbrt, cbrt, double) GG_M1(gs_exp2, exp2, double)
    GG_M1(gs_expm1, expm1, double) GG_M1(gs_log1p, log1p, double) GG_M1(gs_sinh, sinh, double) GG_M1(gs_cosh, cosh, double)
    GG_M1(gs_tanh, tanh, double)
    GG_M1(gs_sqrtf, sqrtf, float) GG_M1(gs_sinf, sinf, float) GG_M1(gs_cosf, cosf, float) GG_M1(gs_tanf, tanf, float)
    GG_M1(gs_asinf, asinf, float) GG_M1(gs_acosf, acosf, float) GG_M1(gs_atanf, atanf, float) GG_M2(gs_atan2f, atan2f, float)
    GG_M1(gs_expf, expf, float) GG_M1(gs_logf, logf, float) GG_M1(gs_log2f, log2f, float) GG_M1(gs_log10f, log10f, float)
    GG_M2(gs_powf, powf, float) GG_M2(gs_hypotf, hypotf, float) GG_M1(gs_cbrtf, cbrtf, float) GG_M1(gs_exp2f, exp2f, float)
    GG_M1(gs_expm1f, expm1f, float) GG_M1(gs_log1pf, log1pf, float) GG_M1(gs_sinhf, sinhf, float) GG_M1(gs_coshf, coshf, float)
    GG_M1(gs_tanhf, tanhf, float)
    static double gs_mul_add(double x, double y, double z) { return fma(x, y, z); }
    static float gs_mul_addf(float x, float y, float z) { return fmaf(x, y, z); }
    static int64_t gs_popcount(uint64_t x) { int64_t n = 0; while (x) { x &= x - 1; n++; } return n; }
    static int64_t gs_clz(uint64_t x) { int64_t n = 0; if (!x) return 64; while (!(x >> 63)) { x <<= 1; n++; } return n; }
    static int64_t gs_ctz(uint64_t x) { int64_t n = 0; if (!x) return 64; while (!(x & 1)) { x >>= 1; n++; } return n; }
    static uint32_t gs_rotl32(uint32_t x, int64_t n) { uint32_t s = (uint32_t)n & 31; return (x << s) | (x >> (-s & 31)); }
    static uint64_t gs_rotl64(uint64_t x, int64_t n) { uint32_t s = (uint32_t)n & 63; return (x << s) | (x >> (-s & 63)); }
    static uint32_t gs_rotr32(uint32_t x, int64_t n) { uint32_t s = (uint32_t)n & 31; return (x >> s) | (x << (-s & 31)); }
    static uint64_t gs_rotr64(uint64_t x, int64_t n) { uint32_t s = (uint32_t)n & 63; return (x >> s) | (x << (-s & 63)); }
    static uint16_t gs_byte_swap16(uint16_t x) { return (uint16_t)((x << 8) | (x >> 8)); }
    static uint32_t gs_byte_swap32(uint32_t x) { return (x << 24) | ((x & 0xFF00) << 8) | ((x >> 8) & 0xFF00) | (x >> 24); }
    static uint64_t gs_byte_swap64(uint64_t x) { return ((uint64_t)gs_byte_swap32((uint32_t)x) << 32) | gs_byte_swap32((uint32_t)(x >> 32)); }
    /* A ByteSet starts with its members: one bool per byte value. */
    static int64_t gs_find_any(gg_slice s, const void *set) {
        const uint8_t *m = set, *p = s.data; int64_t i;
        for (i = 0; i < s.len; i++) if (m[p[i]]) return i;
        return -1;
    }
    static int64_t gs_find_pair(gg_slice s, const void *a, int64_t d, const void *b) {
        const uint8_t *ma = a, *mb = b, *p = s.data; int64_t i;
        for (i = 0; i + d < s.len; i++) if (ma[p[i]] && mb[p[i + d]]) return i;
        return -1;
    }
    /* The shortest digits that read back as x, finite and not zero: their count,
       and the power of ten they are a fraction of, 0.d1 d2 ... dn * 10^point. */
    static int64_t gs_f64_digits(double x, gg_slice out, int64_t *point) {
        char b[40]; int precision, n = 0, i; char *e;
        if (x != x || x - x != 0 || x == 0) return 0;
        for (precision = 0; precision < 17; precision++) {
            snprintf(b, sizeof b, "%.*e", precision, x);
            if (strtod(b, NULL) == x) break;
        }
        e = strchr(b, 'e');
        for (i = 0; b + i < e; i++) if (b[i] >= '0' && b[i] <= '9' && n < out.len) ((uint8_t *)out.data)[n++] = (uint8_t)b[i];
        while (n > 1 && ((uint8_t *)out.data)[n - 1] == '0') n--;
        *point = strtol(e + 1, NULL, 10) + 1;
        return n;
    }
    static float gs_f32_from_bits(uint32_t b) { float v; memcpy(&v, &b, 4); return v; }
    static double gs_f64_from_bits(uint64_t b) { double v; memcpy(&v, &b, 8); return v; }
    static uint32_t gs_f32_to_bits(float v) { uint32_t b; memcpy(&b, &v, 4); return b; }
    static uint64_t gs_f64_to_bits(double v) { uint64_t b; memcpy(&b, &v, 8); return b; }
    static uint8_t gs_trim_memory(void) { return 1; }
    static uint8_t gs_ffi_cstr(uint64_t p, gg_reference out) { if (!p) return 0; gg_append(out, (const void *)(uintptr_t)p, (int64_t)strlen((const char *)(uintptr_t)p), 1); return 1; }
    static uint8_t gs_ffi_bytes(uint64_t p, int64_t n, gg_reference out) { if (!p || n < 0) return 0; gg_append(out, (const void *)(uintptr_t)p, n, 1); return 1; }
    #ifndef _WIN32
    static int gg_kind(gg_slice path) { struct stat st; char *p = gg_cstring(path); int r = stat(p, &st); free(p); if (r) return 0; return S_ISDIR(st.st_mode) ? 2 : 1; }
    static uint8_t gs_os_is_dir(gg_slice path) { return gg_kind(path) == 2; }
    static uint8_t gs_os_make_dir(gg_slice path) { char *p = gg_cstring(path); mkdir(p, 0777); free(p); return gg_kind(path) == 2; }
    static uint8_t gs_os_remove_dir(gg_slice path) { char *p = gg_cstring(path); int r = gg_kind(path) == 2 ? rmdir(p) : -1; free(p); return r == 0; }
    static uint8_t gs_os_remove_file(gg_slice path) { char *p = gg_cstring(path); int r = gg_kind(path) == 1 ? unlink(p) : -1; free(p); return r == 0; }
    static uint8_t gs_os_rename_file(gg_slice from, gg_slice to) { char *a = gg_cstring(from), *b = gg_cstring(to); int r = rename(a, b); free(a); free(b); return r == 0; }
    static uint8_t gs_os_append_file(gg_slice path, gg_slice data) {
        char *p = gg_cstring(path); FILE *f = fopen(p, "ab"); int ok; free(p); if (!f) return 0;
        ok = !data.len || fwrite(data.data, 1, (size_t)data.len, f) == (size_t)data.len; if (fclose(f)) ok = 0; return (uint8_t)ok;
    }
    static uint8_t gs_os_write_file_atomic(gg_slice path, gg_slice data) {
        char *p = gg_cstring(path), *t = malloc((size_t)path.len + 16); int ok; gg_slice tv;
        sprintf(t, "%s.tmp%d", p, (int)getpid()); tv = gg_view(t, (int64_t)strlen(t));
        ok = gs_os_write_file(tv, data) && rename(t, p) == 0; if (!ok) unlink(t); free(p); free(t); return (uint8_t)ok;
    }
    static int gg_name_order(const void *a, const void *b) { return strcmp(*(char *const *)a, *(char *const *)b); }
    static uint8_t gs_os_list_dir(gg_slice path, gg_reference out) {
        char *p = gg_cstring(path), **names = NULL; size_t count = 0, i; struct dirent *e; DIR *d = opendir(p); free(p);
        if (!d) return 0;
        while ((e = readdir(d)) != NULL) {
            if (e->d_name[0] == '.' && (!e->d_name[1] || (e->d_name[1] == '.' && !e->d_name[2]))) continue;
            names = realloc(names, (count + 1) * sizeof *names); names[count++] = strdup(e->d_name);
        }
        closedir(d);
        qsort(names, count, sizeof *names, gg_name_order);
        for (i = 0; i < count; i++) { gg_append(out, names[i], (int64_t)strlen(names[i]), 1); gg_append(out, "\n", 1, 1); free(names[i]); }
        free(names); return 1;
    }
    static uint8_t gs_os_read_line(gg_reference out) {
        int c = getchar(); int64_t start = out.header->len; uint8_t b;
        if (c == EOF) return 0;
        while (c != EOF && c != '\n') { b = (uint8_t)c; gg_append(out, &b, 1, 1); c = getchar(); }
        if (c == '\n' && out.header->len > start && out.header->base[out.header->len - 1] == '\r') gg_resize(out, out.header->len - 1, 1, NULL);
        return 1;
    }
    static void gs_os_read_stdin(gg_reference out) { unsigned char b[65536]; size_t n; while ((n = fread(b, 1, sizeof b, stdin)) != 0) gg_append(out, b, (int64_t)n, 1); }
    static uint8_t gs_os_read_stdin_max(gg_reference out, int64_t max) {
        unsigned char b[65536]; int64_t got = 0; size_t n, want;
        while (got < max) { want = max - got < (int64_t)sizeof b ? (size_t)(max - got) : sizeof b; n = fread(b, 1, want, stdin); if (!n) break; gg_append(out, b, (int64_t)n, 1); got += (int64_t)n; }
        return got > 0;
    }
    static uint8_t gs_os_getenv(gg_slice name, gg_reference out) { char *n = gg_cstring(name); const char *v = getenv(n); free(n); if (!v) return 0; gg_append(out, v, (int64_t)strlen(v), 1); return 1; }
    static uint8_t gs_os_resource_dir(gg_reference out) {
        char b[4096]; ssize_t n = readlink("/proc/self/exe", b, sizeof b);
        if (n <= 0 || n >= (ssize_t)sizeof b) return 0;
        while (n > 0 && b[n - 1] != '/') n--;
        gg_append(out, b, (int64_t)n, 1); return 1;
    }
    static int64_t gs_os_time_ns(void) { struct timespec t; clock_gettime(CLOCK_REALTIME, &t); return (int64_t)t.tv_sec * 1000000000 + t.tv_nsec; }
    static int64_t gs_os_clock_ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (int64_t)t.tv_sec * 1000000000 + t.tv_nsec; }
    static void gs_os_sleep_ms(int64_t ms) { struct timespec t; if (ms <= 0) return; t.tv_sec = ms / 1000; t.tv_nsec = (ms % 1000) * 1000000; nanosleep(&t, NULL); }
    static uint64_t gs_os_random_u64(void) {
        uint64_t v = 0; FILE *f = fopen("/dev/urandom", "rb");
        if (!f || fread(&v, sizeof v, 1, f) != 1) v = (uint64_t)gs_os_clock_ns() * 0x9E3779B97F4A7C15ull;
        if (f) fclose(f); return v;
    }
    #endif
    """;
}

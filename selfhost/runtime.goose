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
    static void gg_fail(const char *message) {
        fprintf(stderr, "goose runtime error: %s\n", message); exit(1);
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
    static void gg_float(gg_reference out,double n) { char b[64];int k=snprintf(b,sizeof b,"%.15g",n);if(strtod(b,NULL)!=n)k=snprintf(b,sizeof b,"%.17g",n);gg_append(out,b,k,1); }
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
    static uint8_t gs_os_file_exists(gg_slice path) { char*p=gg_cstring(path);FILE*f=fopen(p,"rb");free(p);if(!f)return 0;fclose(f);return 1; }
    static void gs_os_write_stdout(gg_slice s) { gg_write(stdout,s); }
    static void gs_os_write_stderr(gg_slice s) { gg_write(stderr,s); }
    static void gs_os_flush_stdout(void) { fflush(stdout); }
    static int64_t gs_os_arg_count(void) { return gg_argc; }
    static void gs_os_arg(int64_t i,gg_reference out) { if(i>=0 && i<gg_argc)gg_append(out,gg_argv[i],(int64_t)strlen(gg_argv[i]),1); }
    """;
}

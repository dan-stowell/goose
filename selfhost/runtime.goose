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
    #include <unistd.h>
    #endif
    typedef struct { void *data; int64_t len; } gg_slice;
    typedef struct { unsigned char *base; int64_t len; } gg_header;
    typedef struct { unsigned char *base; size_t top, committed; } gg_stack;
    typedef struct { gg_header *header; gg_stack *stack; } gg_reference;
    #define GG_RESERVATION ((size_t)268435456)
    #define GG_STACK_COUNT 8192
    static gg_stack gg_stacks[GG_STACK_COUNT];
    static gg_stack gg_slot_stacks[GG_STACK_COUNT];
    static unsigned char gg_pool_busy[GG_STACK_COUNT];
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
    static gg_stack *gg_reserve_stack(gg_stack *s) {
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
    static gg_stack *gg_get_stack(int64_t id) {
        if (id < 0 || id >= GG_STACK_COUNT) gg_fail("data stack limit exceeded");
        return gg_reserve_stack(&gg_stacks[id]);
    }
    static void gg_reset_pool(gg_stack *s) {
        ptrdiff_t id = s - gg_stacks;
        gg_slot_stacks[id].top = 0; gg_pool_busy[id] = 0;
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
        if (gg_pool_busy[a.stack - gg_stacks]) gg_fail("pool growth during element construction");
        if (n < 0 || (uint64_t)n > GG_RESERVATION / (element ? element : 1)) gg_fail("invalid array size");
        to=gg_allocate(a.stack, (size_t)n * element);
        if (n && element) memmove(to, p, (size_t)n * element);
        a.header->len += n;
    }
    static void gg_pool_free(gg_reference a, uint64_t index) {
        gg_stack *slots;
        int64_t i = (int64_t)index;
        if (index >= (uint64_t)a.header->len) {
            fprintf(stderr, "goose runtime error: index %lld out of bounds (length %lld)\n", (long long)i, (long long)a.header->len); exit(1);
        }
        slots = gg_reserve_stack(&gg_slot_stacks[a.stack - gg_stacks]);
        memcpy(gg_allocate(slots, sizeof i), &i, sizeof i);
    }
    static int64_t gg_pool_claim(gg_reference a, size_t element) {
        ptrdiff_t id = a.stack - gg_stacks;
        gg_stack *slots = &gg_slot_stacks[id];
        int64_t index = a.header->len;
        if (gg_pool_busy[id]) gg_fail("pool growth during element construction");
        if (slots->top) { slots->top -= sizeof index; memcpy(&index, slots->base + slots->top, sizeof index); }
        else gg_allocate(a.stack, element);
        gg_pool_busy[id] = 1;
        return index;
    }
    static void gg_pool_finish(gg_reference a, int64_t index) {
        if (index == a.header->len) a.header->len++;
        gg_pool_busy[a.stack - gg_stacks] = 0;
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
    static void *gg_push_slot(gg_reference a, size_t element) {
        void *to; if (gg_pool_busy[a.stack - gg_stacks]) gg_fail("pool growth during element construction");
        to = gg_allocate(a.stack, element); if (element) memset(to, 0, element); a.header->len++; return to;
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
    static void gg_move_from(gg_slice dst, gg_slice src, size_t element) {
        if (dst.len != src.len) gg_fail("move_from lengths differ");
        if (dst.len && element) memmove(dst.data, src.data, (size_t)dst.len * element);
    }
    static void gg_little_endian(void) {
        const uint16_t one = 1;
        if (*(const uint8_t *)&one != 1) gg_fail("serialization needs a little-endian host (not supported yet)");
    }
    static void gg_builtin_fail(gg_slice message, const char *fallback, const char *location) {
        if (!message.data) { fprintf(stderr, "goose runtime error: %s%s\n", fallback, location); exit(1); }
        fputs("goose runtime error: ", stderr);
        if (message.len) fwrite(message.data, 1, (size_t)message.len, stderr);
        fprintf(stderr, "%s\n", location); exit(1);
    }
    static int64_t gg_check_length(uint64_t n, size_t element, gg_slice message, const char *location) {
        if (n > (element ? GG_RESERVATION / element : INT64_MAX)) gg_builtin_fail(message, "invalid array length", location);
        return (int64_t)n;
    }
    static int64_t gg_range_index(gg_slice a, gg_slice s, size_t element, gg_slice message, const char *location) {
        uint64_t offset, index;
        if (!element) {
            if ((uint64_t)s.len > (uint64_t)a.len) gg_builtin_fail(message, "slice not within this array", location);
            return 0;
        }
        if (!s.len) return 0;
        offset = (uintptr_t)s.data - (uintptr_t)a.data;
        index = offset / element;
        if (offset % element || index >= (uint64_t)a.len || (uint64_t)s.len > (uint64_t)a.len - index)
            gg_builtin_fail(message, "slice not within this array", location);
        return (int64_t)index;
    }
    typedef struct { int64_t start, len; } gg_span;
    static gg_stack *gg_span_stack(gg_reference a) {
        return &gg_slot_stacks[a.stack - gg_stacks];
    }
    static void gg_span_remove(gg_stack *s, size_t i) {
        size_t count = s->top / sizeof(gg_span);
        gg_span *spans = (gg_span *)s->base;
        if (i + 1 < count) memmove(spans + i, spans + i + 1, (count - i - 1) * sizeof(gg_span));
        s->top -= sizeof(gg_span);
    }
    static void gg_span_free(gg_reference a, int64_t start, int64_t len) {
        gg_stack *s = gg_span_stack(a);
        gg_span *spans;
        size_t count = s->top / sizeof(gg_span), first = 0, after;
        int64_t end;
        if (!len) return;
        end = start + len;
        spans = (gg_span *)s->base;
        while (first < count && spans[first].start + spans[first].len < start) first++;
        after = first;
        while (after < count && spans[after].start <= end) {
            if (spans[after].start < start) start = spans[after].start;
            if (spans[after].start + spans[after].len > end) end = spans[after].start + spans[after].len;
            after++;
        }
        if (after == first) {
            gg_reserve_stack(s); gg_allocate(s, sizeof(gg_span));
            spans = (gg_span *)s->base;
            if (first < count) memmove(spans + first + 1, spans + first, (count - first) * sizeof(gg_span));
        } else {
            if (after < count) memmove(spans + first + 1, spans + after, (count - after) * sizeof(gg_span));
            s->top -= (after - first - 1) * sizeof(gg_span);
        }
        spans[first].start = start; spans[first].len = end - start;
    }
    static int64_t gg_pool_slice_length(uint64_t n, size_t element) {
        if (!element || n > GG_RESERVATION / element || n > INT64_MAX) gg_fail("invalid slice length");
        return (int64_t)n;
    }
    static int64_t gg_pool_slice_index(gg_reference a, gg_slice slice, size_t element) {
        uint64_t offset, index;
        if (!slice.len) return 0;
        if (!element) gg_fail("slice not from this pool");
        offset = (uintptr_t)slice.data - (uintptr_t)a.header->base;
        index = offset / element;
        if (offset % element || index >= (uint64_t)a.header->len ||
            (uint64_t)slice.len > (uint64_t)a.header->len - index)
            gg_fail("slice not from this pool");
        return (int64_t)index;
    }
    static void gg_pool_slice_extend(gg_reference a, int64_t start, int64_t n, size_t element) {
        int64_t end;
        uint64_t limit = GG_RESERVATION / element;
        if ((uint64_t)start > limit || (uint64_t)n > limit - (uint64_t)start) gg_fail("invalid slice length");
        end = start + n;
        if (end > a.header->len) {
            gg_allocate(a.stack, (size_t)(end - a.header->len) * element);
            a.header->len = end;
        }
    }
    static int64_t gg_span_place(gg_reference a, int64_t n) {
        gg_stack *s = gg_span_stack(a);
        gg_span *spans = (gg_span *)s->base;
        size_t count = s->top / sizeof(gg_span), i;
        int64_t start;
        if (!n) return a.header->len;
        for (i = 0; i < count; i++) {
            if (spans[i].len < n) continue;
            start = spans[i].start;
            if (spans[i].len == n) gg_span_remove(s, i);
            else { spans[i].start += n; spans[i].len -= n; }
            return start;
        }
        if (count && spans[count - 1].start + spans[count - 1].len == a.header->len) {
            start = spans[count - 1].start; gg_span_remove(s, count - 1); return start;
        }
        return a.header->len;
    }
    static gg_slice gg_pool_slice_alloc(gg_reference a, uint64_t count, size_t element) {
        int64_t n, start;
        if (gg_pool_busy[a.stack - gg_stacks]) gg_fail("pool growth during element construction");
        n = gg_pool_slice_length(count, element);
        start = gg_span_place(a, n);
        gg_pool_slice_extend(a, start, n, element);
        return gg_view(a.header->base + (size_t)start * element, n);
    }
    static void gg_pool_slice_free(gg_reference a, gg_slice slice, size_t element) {
        int64_t start = gg_pool_slice_index(a, slice, element);
        gg_span_free(a, start, slice.len);
    }
    static gg_slice gg_pool_slice_realloc(gg_reference a, gg_slice old, uint64_t count, size_t element) {
        int64_t n, start, previous;
        gg_stack *s;
        gg_span *spans;
        size_t span_count, i;
        if (gg_pool_busy[a.stack - gg_stacks]) gg_fail("pool growth during element construction");
        n = gg_pool_slice_length(count, element);
        start = gg_pool_slice_index(a, old, element);
        if (n <= old.len) {
            gg_span_free(a, start + n, old.len - n);
            return gg_view(a.header->base + (size_t)start * element, n);
        }
        if (!old.len) return gg_pool_slice_alloc(a, count, element);
        previous = start;
        if (start + old.len != a.header->len) {
            s = gg_span_stack(a); spans = (gg_span *)s->base;
            span_count = s->top / sizeof(gg_span);
            for (i = 0; i < span_count && spans[i].start < start + old.len; i++) {}
            if (i < span_count && spans[i].start == start + old.len &&
                (spans[i].len >= n - old.len || spans[i].start + spans[i].len == a.header->len)) {
                int64_t extra = n - old.len;
                if (spans[i].len <= extra) gg_span_remove(s, i);
                else { spans[i].start += extra; spans[i].len -= extra; }
            } else {
                gg_span_free(a, start, old.len);
                start = gg_span_place(a, n);
            }
        }
        gg_pool_slice_extend(a, start, n, element);
        if (start != previous) memmove(a.header->base + (size_t)start * element,
                                      a.header->base + (size_t)previous * element,
                                      (size_t)old.len * element);
        return gg_view(a.header->base + (size_t)start * element, n);
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
    static uint8_t gs_os_file_exists(gg_slice path) { char*p=gg_cstring(path);FILE*f=fopen(p,"rb");free(p);if(!f)return 0;fclose(f);return 1; }
    static void gs_os_write_stdout(gg_slice s) { gg_write(stdout,s); }
    static void gs_os_write_stderr(gg_slice s) { gg_write(stderr,s); }
    static void gs_os_flush_stdout(void) { fflush(stdout); }
    static int64_t gs_os_arg_count(void) { return gg_argc; }
    static void gs_os_arg(int64_t i,gg_reference out) { if(i>=0 && i<gg_argc)gg_append(out,gg_argv[i],(int64_t)strlen(gg_argv[i]),1); }
    """;
}

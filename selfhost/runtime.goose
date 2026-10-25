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
        if (n < 0) gg_fail("negative array length");
        if (n > old) {
            unsigned char *p;
            if (!fill) gg_fail("resize without fill may only shrink");
            if ((uint64_t)(n-old) > GG_RESERVATION / (element ? element : 1)) gg_fail("invalid array size");
            p=gg_allocate(a.stack, (size_t)(n-old)*element);
            for (i=0; i<n-old; i++) if(element) memcpy(p+(size_t)i*element, fill, element);
        } else { a.stack->top = (size_t)(a.header->base-a.stack->base) + (size_t)n*element; }
        a.header->len=n;
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
    /* Build the exact decimal digits before rounding. Trying only the nearest
       spelling can miss a shortest spelling across a power-of-two boundary,
       where the two round-trip margins have different widths. */
    static int gg_float_matches(double n, int narrow, uint64_t m, int exponent) {
        char b[40];
        snprintf(b,sizeof b,"%llue%+d",(unsigned long long)m,exponent);
        return narrow ? strtof(b,NULL)==(float)n : strtod(b,NULL)==n;
    }
    static void gg_float(gg_reference out,double n,int narrow) {
        unsigned char exact[1100];
        char digits[32], b[64];
        uint64_t bits, m, rounded=0;
        int binary, scale=0, len=0, i, j, carry, factor, p, q=0, up, tail, k, e, pos=0;
        if(narrow) n=(float)n;
        memcpy(&bits,&n,sizeof bits);
        binary=(int)((bits>>52)&2047);
        m=bits&UINT64_C(4503599627370495);
        if(binary==2047) {
            if(m) gg_append(out,"nan",3,1);
            else gg_append(out,bits>>63?"-inf":"inf",bits>>63?4:3,1);
            return;
        }
        if(bits>>63) { b[pos++]='-'; n=-n; }
        if(!binary && !m) {
            memcpy(b+pos,"0.0",3); gg_append(out,b,pos+3,1); return;
        }
        if(binary) { m|=UINT64_C(4503599627370496); binary-=1075; }
        else binary=-1074;
        do { exact[len++]=(unsigned char)(m%10); m/=10; } while(m);
        /* Multiplying by 5 and shifting the decimal point is division by 2.
           Even the smallest f64 needs fewer than 1100 exact decimal digits. */
        factor=binary<0?5:2;
        if(binary<0) { scale=binary; binary=-binary; }
        for(i=0;i<binary;i++) {
            carry=0;
            for(j=0;j<len;j++) { carry+=exact[j]*factor; exact[j]=(unsigned char)(carry%10); carry/=10; }
            if(carry) exact[len++]=(unsigned char)carry;
        }
        for(p=1;p<=(narrow?9:17);p++) {
            m=0;
            for(i=len-1;i>=0 && i>=len-p;i--) m=m*10+exact[i];
            q=scale+(len>p?len-p:0); rounded=m;
            if(p>=len) break;
            tail=0;
            for(i=0;i<len-p-1;i++) if(exact[i]) tail=1;
            up=exact[len-p-1]>5 || (exact[len-p-1]==5 && (tail || (m&1)));
            if(up) rounded++;
            if(gg_float_matches(n,narrow,rounded,q)) break;
            /* The nearest candidate failed. Only its neighbor across the
               exact value can lie inside the other round-trip margin. */
            m=up?rounded-1:rounded+1;
            if(gg_float_matches(n,narrow,m,q)) { rounded=m; break; }
        }
        while(rounded%10==0) { rounded/=10; q++; }
        k=snprintf(digits,sizeof digits,"%llu",(unsigned long long)rounded);
        e=q+k-1;
        /* The observed layout uses general notation with at least 15 digits
           of precision, even when the shortest significand has fewer. */
        if(e < -4 || e >= (k>15?k:15)) {
            b[pos++]=digits[0];
            if(k>1) { b[pos++]='.'; memcpy(b+pos,digits+1,(size_t)k-1); pos+=k-1; }
            pos+=snprintf(b+pos,sizeof b-(size_t)pos,"e%+03d",e);
        } else if(e<0) {
            b[pos++]='0'; b[pos++]='.';
            for(i=-1;i>e;i--) b[pos++]='0';
            memcpy(b+pos,digits,(size_t)k); pos+=k;
        } else {
            for(i=0;i<=e || i<k;i++) {
                if(i==e+1) b[pos++]='.';
                b[pos++]=i<k?digits[i]:'0';
            }
            if(q>=0) { b[pos++]='.'; b[pos++]='0'; }
        }
        gg_append(out,b,pos,1);
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

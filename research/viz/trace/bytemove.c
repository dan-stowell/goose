/* bytemove: a Valgrind tool that replays every data access of a program
   through a model of this VM's cache hierarchy (AMD EPYC 9554P, Zen 4:
   L1D 32 KB 8-way, L2 1 MB 8-way inclusive of L1, L3 32 MB 16-way victim
   cache of L2, 64-byte lines, LRU, no hardware prefetch) and records, for
   every access, which level served it.

   Output (in --out=DIR):
     samples.bin  u64 per sampled access (on average one in --sample=N,
                  pseudo-random skips so loops do not alias):
                  bits 0-47 address, 48-49 level (0 L1, 1 L2, 2 L3, 3 memory),
                  50 write, 51-55 stage index.
     agg.tsv      exact counts: stage, 64 KB chunk, level, rw -> accesses.
     events.tsv   stage transitions, mmaps, munmaps, brk, memory dumps,
                  totals, each with the access ordinal at which it happened.
     dump-K.bin   raw bytes of --dump=ADDR:LEN taken at each stage change.

   Stages come from --marks=NAME=STAGE:MODE,... where NAME is a function
   symbol (matched as a prefix ending at '(' '.' or end of name), STAGE a
   small name, MODE 's' (sticky: the thread's stage from its entry on) or
   'e' (extent: the stage only while that call is active, tracked by the
   stack pointer). Built against the installed valgrind 3.22 headers and
   libraries; see build.sh. */

#include "pub_tool_basics.h"
#include "pub_tool_tooliface.h"
#include "pub_tool_libcassert.h"
#include "pub_tool_libcprint.h"
#include "pub_tool_libcbase.h"
#include "pub_tool_libcfile.h"
#include "pub_tool_mallocfree.h"
#include "pub_tool_options.h"
#include "pub_tool_machine.h"
#include "pub_tool_threadstate.h"
#include "pub_tool_debuginfo.h"
#include "pub_tool_vki.h"
#include "pub_tool_aspacemgr.h"
#include "libvex_guest_amd64.h"

/* ---------------- options ---------------- */
static const HChar *clo_out = "bytemove.out";
static const HChar *clo_marks = "";
static const HChar *clo_dump = "";
static Long clo_sample = 64;
static Bool clo_debug = False;

#define MAX_STAGES 16
#define MAX_MARKS 32
static HChar *stage_names[MAX_STAGES];
static Int n_stages = 1; /* stage 0 = "start" */
static struct { HChar *name; Int stage; Bool extent; } marks[MAX_MARKS];
static Int n_marks = 0;
static Addr dump_addr = 0; static SizeT dump_len = 0;

static Int stage_index(const HChar *s) {
   for (Int i = 0; i < n_stages; i++) if (VG_(strcmp)(stage_names[i], s) == 0) return i;
   tl_assert(n_stages < MAX_STAGES);
   stage_names[n_stages] = VG_(strdup)("bm.st", s);
   return n_stages++;
}

static void parse_marks(void) {
   stage_names[0] = (HChar *)"start";
   HChar *s = VG_(strdup)("bm.m", clo_marks);
   HChar *p = s;
   while (*p) {
      HChar *comma = VG_(strchr)(p, ',');
      if (comma) *comma = 0;
      HChar *eq = VG_(strchr)(p, '=');
      HChar *colon = eq ? VG_(strchr)(eq, ':') : NULL;
      if (eq && colon) {
         *eq = 0; *colon = 0;
         tl_assert(n_marks < MAX_MARKS);
         marks[n_marks].name = p;
         marks[n_marks].stage = stage_index(eq + 1);
         marks[n_marks].extent = colon[1] == 'e';
         n_marks++;
      }
      if (!comma) break;
      p = comma + 1;
   }
   if (clo_dump[0]) {
      const HChar *q = clo_dump;
      HChar *end;
      dump_addr = (Addr)VG_(strtoull16)(q, &end);
      if (*end == ':') dump_len = (SizeT)VG_(strtoull10)(end + 1, &end);
   }
}

static Bool bm_process_cmd_line_option(const HChar *arg) {
   if VG_STR_CLO(arg, "--out", clo_out) {}
   else if VG_STR_CLO(arg, "--marks", clo_marks) {}
   else if VG_STR_CLO(arg, "--dump", clo_dump) {}
   else if VG_INT_CLO(arg, "--sample", clo_sample) {}
   else if VG_BOOL_CLO(arg, "--debug-marks", clo_debug) {}
   else return False;
   return True;
}
static void bm_print_usage(void) {
   VG_(printf)("    --out=DIR --marks=fn=stage:s|e,... --dump=HEXADDR:LEN --sample=N\n");
}
static void bm_print_debug_usage(void) {}

/* ---------------- output ---------------- */
static Int fd_samples = -1, fd_events = -1;
static HChar pathbuf[4096];
static ULong *sbuf; static Int sbuf_n = 0;
#define SBUF_CAP 65536

static Int open_out(const HChar *name) {
   VG_(snprintf)(pathbuf, sizeof pathbuf, "%s/%s", clo_out, name);
   SysRes r = VG_(open)(pathbuf, VKI_O_CREAT | VKI_O_TRUNC | VKI_O_WRONLY, 0644);
   if (sr_isError(r)) { VG_(fmsg)("bytemove: cannot open %s\n", pathbuf); VG_(exit)(1); }
   return sr_Res(r);
}
static void ev(const HChar *fmt, ...) {
   HChar b[1024];
   va_list vargs; va_start(vargs, fmt);
   Int n = VG_(vsnprintf)(b, sizeof b, fmt, vargs);
   va_end(vargs);
   VG_(write)(fd_events, b, n);
}
static void flush_samples(void) {
   if (sbuf_n) VG_(write)(fd_samples, sbuf, sbuf_n * 8);
   sbuf_n = 0;
}

/* ---------------- cache model ---------------- */
#define LINE_SHIFT 6
typedef struct { Int sets, ways; ULong *tags; } Cache; /* tag = line<<1 | dirty; ~0 empty */
static Cache L1, L2, L3;
static ULong wb_to_mem = 0;   /* dirty lines written back to memory */

static void cache_init(Cache *c, Int size, Int ways) {
   c->ways = ways; c->sets = size / 64 / ways;
   c->tags = VG_(malloc)("bm.cache", sizeof(ULong) * c->sets * ways);
   for (Int i = 0; i < c->sets * ways; i++) c->tags[i] = ~0ULL;
}
/* Look the line up; on a hit move it to MRU, OR in dirty, return 1.
   remove: on a hit take it out instead (exclusive L3), returning its dirty
   bit via *dirty. */
static inline Int cache_lookup(Cache *c, ULong line, Bool write, Bool remove, Bool *dirty) {
   ULong *set = c->tags + (line & (c->sets - 1)) * c->ways;
   for (Int w = 0; w < c->ways; w++) {
      if ((set[w] >> 1) == line && set[w] != ~0ULL) {
         ULong t = set[w] | (write ? 1 : 0);
         if (remove) {
            if (dirty) *dirty = t & 1;
            for (Int k = w; k < c->ways - 1; k++) set[k] = set[k + 1];
            set[c->ways - 1] = ~0ULL;
            return 1;
         }
         for (Int k = w; k > 0; k--) set[k] = set[k - 1];
         set[0] = t;
         return 1;
      }
   }
   return 0;
}
/* Insert at MRU; return the victim tag (~0 if none). */
static inline ULong cache_insert(Cache *c, ULong line, Bool dirty) {
   ULong *set = c->tags + (line & (c->sets - 1)) * c->ways;
   ULong victim = set[c->ways - 1];
   for (Int k = c->ways - 1; k > 0; k--) set[k] = set[k - 1];
   set[0] = (line << 1) | (dirty ? 1 : 0);
   return victim;
}
static inline void mark_dirty(Cache *c, ULong line) {
   ULong *set = c->tags + (line & (c->sets - 1)) * c->ways;
   for (Int w = 0; w < c->ways; w++) if (set[w] != ~0ULL && (set[w] >> 1) == line) { set[w] |= 1; return; }
}
static inline Int sim_line(ULong line, Bool write) {
   if (cache_lookup(&L1, line, write, False, NULL)) return 0;
   Int level;
   Bool l3dirty = False;
   if (cache_lookup(&L2, line, False, False, NULL)) level = 1;
   else {
      level = cache_lookup(&L3, line, False, True, &l3dirty) ? 2 : 3;
      ULong v = cache_insert(&L2, line, l3dirty);
      if (v != ~0ULL) {
         ULong v3 = cache_insert(&L3, v >> 1, v & 1);
         if (v3 != ~0ULL && (v3 & 1)) wb_to_mem++;
      }
   }
   ULong v1 = cache_insert(&L1, line, write);
   if (v1 != ~0ULL && (v1 & 1)) mark_dirty(&L2, v1 >> 1);
   return level;
}

/* ---------------- stages per thread ---------------- */
#define MAX_TIDS 64
#define MAX_DEPTH 64
typedef struct {
   Int base;               /* sticky stage */
   Int depth;
   Addr sp[MAX_DEPTH]; Int st[MAX_DEPTH];
   Addr sp_min, sp_max;
} TState;
static TState ts[MAX_TIDS];
static Int cur_stage = 0, last_tid = -1;
static Int seen_stage[MAX_STAGES];
static ULong n_access = 0, n_instr = 0, n_samples = 0;
static Int dump_count = 0;

static void recompute_stage(Int tid) {
   TState *t = &ts[tid];
   cur_stage = t->depth ? t->st[t->depth - 1] : t->base;
}
static void note_stage(Int tid) {
   static Int prev = -1;
   if (cur_stage == prev) return;
   prev = cur_stage;
   ev("stage\t%s\t%llu\t%llu\t%llu\t%d\n", stage_names[cur_stage], n_access, n_samples, n_instr, tid);
   if (!seen_stage[cur_stage] && dump_len) {
      seen_stage[cur_stage] = 1;
      HChar name[64];
      VG_(snprintf)(name, sizeof name, "dump-%d.bin", dump_count);
      Int fd = open_out(name);
      if (VG_(am_is_valid_for_client)(dump_addr, dump_len, VKI_PROT_READ))
         VG_(write)(fd, (void *)dump_addr, dump_len);
      VG_(close)(fd);
      ev("dump\t%d\t%s\t%llu\n", dump_count, stage_names[cur_stage], n_access);
      dump_count++;
   }
}

static VG_REGPARM(2) void on_sb(Addr sp, ULong ninstr) {
   n_instr += ninstr;
   Int tid = VG_(get_running_tid)();
   if (tid >= MAX_TIDS) tid = MAX_TIDS - 1;
   TState *t = &ts[tid];
   if (!t->sp_max || sp > t->sp_max) t->sp_max = sp;
   if (!t->sp_min || sp < t->sp_min) t->sp_min = sp;
   Bool changed = tid != last_tid;
   while (t->depth && sp > t->sp[t->depth - 1]) { t->depth--; changed = True; }
   if (changed) { last_tid = tid; recompute_stage(tid); note_stage(tid); }
}
static VG_REGPARM(2) void on_mark(Addr sp, ULong m) {
   Int tid = VG_(get_running_tid)();
   if (tid >= MAX_TIDS) tid = MAX_TIDS - 1;
   TState *t = &ts[tid];
   if (marks[m].extent) {
      if (t->depth < MAX_DEPTH) { t->sp[t->depth] = sp; t->st[t->depth] = marks[m].stage; t->depth++; }
   } else {
      t->base = marks[m].stage;
   }
   last_tid = tid;
   recompute_stage(tid); note_stage(tid);
}

/* ---------------- exact aggregates ---------------- */
typedef struct { ULong key; ULong n[8]; } Agg; /* n[level*2 + write] */
static Agg *agg; static ULong agg_cap = 1 << 16, agg_used = 0;
static inline Agg *agg_get(ULong key) {
   ULong h = (key * 0x9E3779B97F4A7C15ULL) >> 40;
   for (;;) {
      Agg *a = &agg[h & (agg_cap - 1)];
      if (a->key == key) return a;
      if (a->key == ~0ULL) {
         if (agg_used * 2 > agg_cap) break;
         a->key = key; agg_used++; return a;
      }
      h++;
   }
   /* grow */
   Agg *old = agg; ULong oc = agg_cap;
   agg_cap *= 2;
   agg = VG_(malloc)("bm.agg", sizeof(Agg) * agg_cap);
   for (ULong i = 0; i < agg_cap; i++) agg[i].key = ~0ULL;
   agg_used = 0;
   for (ULong i = 0; i < oc; i++) if (old[i].key != ~0ULL) { Agg *a = agg_get(old[i].key); *a = old[i]; }
   VG_(free)(old);
   return agg_get(key);
}

static ULong rng = 0x243F6A8885A308D3ULL;
static Long countdown = 1;
static ULong stage_level[MAX_STAGES][8];
static ULong stage_wb[MAX_STAGES];

static inline void access(Addr a, SizeT size, Bool write) {
   ULong first = a >> LINE_SHIFT, last = (a + (size ? size : 1) - 1) >> LINE_SHIFT;
   Int level = 0;
   ULong wb0 = wb_to_mem;
   for (ULong l = first; l <= last; l++) { Int lv = sim_line(l, write); if (lv > level) level = lv; }
   stage_wb[cur_stage] += wb_to_mem - wb0;
   n_access++;
   stage_level[cur_stage][level * 2 + write]++;
   Agg *g = agg_get(((ULong)cur_stage << 48) | (a >> 16));
   g->n[level * 2 + write]++;
   if (--countdown <= 0) {
      rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17;
      countdown = 1 + (Long)(rng % (ULong)(2 * clo_sample - 1));
      sbuf[sbuf_n++] = ((ULong)a & 0xFFFFFFFFFFFFULL) | ((ULong)level << 48) | ((ULong)write << 50)
                       | ((ULong)cur_stage << 51);
      n_samples++;
      if (sbuf_n == SBUF_CAP) flush_samples();
   }
}
static VG_REGPARM(2) void on_load(Addr a, SizeT size) { access(a, size, False); }
static VG_REGPARM(2) void on_store(Addr a, SizeT size) { access(a, size, True); }

/* ---------------- memory map events ---------------- */
static const HChar *seg_name(Addr a) {
   NSegment const *seg = VG_(am_find_nsegment)(a);
   const HChar *n = seg ? VG_(am_get_filename)(seg) : NULL;
   return n ? n : "-";
}
static void on_mmap(Addr a, SizeT len, Bool rr, Bool ww, Bool xx, ULong di) {
   ev("mmap\t%llx\t%llu\t%d%d%d\t%llu\t%s\n", (ULong)a, (ULong)len, rr, ww, xx, n_access, seg_name(a));
}
static void on_munmap(Addr a, SizeT len) { ev("munmap\t%llx\t%llu\t%llu\n", (ULong)a, (ULong)len, n_access); }
static void on_brk(Addr a, SizeT len, ThreadId tid) { ev("brk\t%llx\t%llu\t%llu\n", (ULong)a, (ULong)len, n_access); }
static void on_startup(Addr a, SizeT len, Bool rr, Bool ww, Bool xx, ULong di) {
   ev("startup\t%llx\t%llu\t%d%d%d\t0\t%s\n", (ULong)a, (ULong)len, rr, ww, xx, seg_name(a));
}

/* ---------------- instrumentation ---------------- */
static void add_call(IRSB *sb, const HChar *name, void *fn, IRExpr *addr, Int size, IRExpr *guard) {
   IRExpr **args = mkIRExprVec_2(addr, mkIRExpr_HWord(size));
   IRDirty *d = unsafeIRDirty_0_N(2, name, VG_(fnptr_to_fnentry)(fn), args);
   if (guard) d->guard = guard;
   addStmtToIRSB(sb, IRStmt_Dirty(d));
}

static Int mark_of(Addr pc) {
   if (!n_marks) return -1;
   const HChar *fn;
   if (clo_debug && pc >= 0x4206e0 && pc < 0x420710) ev("pc\t%llx\n", (ULong)pc);
   if (!VG_(get_fnname_if_entry)(VG_(current_DiEpoch)(), pc, &fn)) return -1;
   if (clo_debug) ev("entry\t%llx\t%s\n", (ULong)pc, fn);
   for (Int m = 0; m < n_marks; m++) {
      SizeT n = VG_(strlen)(marks[m].name);
      if (VG_(strncmp)(fn, marks[m].name, n) == 0 && (fn[n] == 0 || fn[n] == '(' || fn[n] == '.'))
         return m;
   }
   return -1;
}

static IRSB *bm_instrument(VgCallbackClosure *closure, IRSB *sbIn, const VexGuestLayout *layout,
                           const VexGuestExtents *vge, const VexArchInfo *archinfo_host,
                           IRType gWordTy, IRType hWordTy) {
   IRSB *sbOut = deepCopyIRSBExceptStmts(sbIn);
   Int i = 0;
   while (i < sbIn->stmts_used && sbIn->stmts[i]->tag != Ist_IMark) {
      addStmtToIRSB(sbOut, sbIn->stmts[i]); i++;
   }
   Int ninstr = 0;
   for (Int j = i; j < sbIn->stmts_used; j++) if (sbIn->stmts[j]->tag == Ist_IMark) ninstr++;
   Bool first = True;
   for (; i < sbIn->stmts_used; i++) {
      IRStmt *st = sbIn->stmts[i];
      if (!st || st->tag == Ist_NoOp) continue;
      switch (st->tag) {
      case Ist_IMark: {
         addStmtToIRSB(sbOut, st);
         IRTemp sp = IRTemp_INVALID;
         Int m = mark_of((Addr)st->Ist.IMark.addr);
         if (first || m >= 0) {
            sp = newIRTemp(sbOut->tyenv, Ity_I64);
            addStmtToIRSB(sbOut, IRStmt_WrTmp(sp, IRExpr_Get(offsetof(VexGuestAMD64State, guest_RSP), Ity_I64)));
         }
         if (first) {
            IRExpr **args = mkIRExprVec_2(IRExpr_RdTmp(sp), mkIRExpr_HWord(ninstr));
            addStmtToIRSB(sbOut, IRStmt_Dirty(unsafeIRDirty_0_N(2, "on_sb", VG_(fnptr_to_fnentry)(on_sb), args)));
            first = False;
         }
         if (m >= 0) {
            IRExpr **args = mkIRExprVec_2(IRExpr_RdTmp(sp), mkIRExpr_HWord(m));
            addStmtToIRSB(sbOut, IRStmt_Dirty(unsafeIRDirty_0_N(2, "on_mark", VG_(fnptr_to_fnentry)(on_mark), args)));
         }
         continue;
      }
      case Ist_WrTmp: {
         IRExpr *e = st->Ist.WrTmp.data;
         if (e->tag == Iex_Load)
            add_call(sbOut, "on_load", on_load, e->Iex.Load.addr, sizeofIRType(e->Iex.Load.ty), NULL);
         break;
      }
      case Ist_Store: {
         IRExpr *data = st->Ist.Store.data;
         add_call(sbOut, "on_store", on_store, st->Ist.Store.addr,
                  sizeofIRType(typeOfIRExpr(sbOut->tyenv, data)), NULL);
         break;
      }
      case Ist_StoreG: {
         IRStoreG *sg = st->Ist.StoreG.details;
         add_call(sbOut, "on_store", on_store, sg->addr,
                  sizeofIRType(typeOfIRExpr(sbOut->tyenv, sg->data)), sg->guard);
         break;
      }
      case Ist_LoadG: {
         IRLoadG *lg = st->Ist.LoadG.details;
         IRType ty = Ity_INVALID, ty2 = Ity_INVALID;
         typeOfIRLoadGOp(lg->cvt, &ty, &ty2);
         add_call(sbOut, "on_load", on_load, lg->addr, sizeofIRType(ty), lg->guard);
         break;
      }
      case Ist_Dirty: {
         IRDirty *d = st->Ist.Dirty.details;
         if (d->mFx != Ifx_None) {
            if (d->mFx == Ifx_Read || d->mFx == Ifx_Modify)
               add_call(sbOut, "on_load", on_load, d->mAddr, d->mSize, NULL);
            if (d->mFx == Ifx_Write || d->mFx == Ifx_Modify)
               add_call(sbOut, "on_store", on_store, d->mAddr, d->mSize, NULL);
         }
         break;
      }
      case Ist_CAS: {
         IRCAS *cas = st->Ist.CAS.details;
         Int sz = sizeofIRType(typeOfIRExpr(sbOut->tyenv, cas->dataLo));
         if (cas->dataHi) sz *= 2;
         add_call(sbOut, "on_load", on_load, cas->addr, sz, NULL);
         add_call(sbOut, "on_store", on_store, cas->addr, sz, NULL);
         break;
      }
      case Ist_LLSC: {
         IRType ty = typeOfIRTemp(sbOut->tyenv, st->Ist.LLSC.result);
         if (st->Ist.LLSC.storedata == NULL)
            add_call(sbOut, "on_load", on_load, st->Ist.LLSC.addr, sizeofIRType(ty), NULL);
         else
            add_call(sbOut, "on_store", on_store, st->Ist.LLSC.addr,
                     sizeofIRType(typeOfIRExpr(sbOut->tyenv, st->Ist.LLSC.storedata)), NULL);
         break;
      }
      default: break;
      }
      addStmtToIRSB(sbOut, st);
   }
   return sbOut;
}

/* ---------------- init / fini ---------------- */
static void bm_post_clo_init(void) {
   parse_marks();
   cache_init(&L1, 32 * 1024, 8);
   cache_init(&L2, 1024 * 1024, 8);
   cache_init(&L3, 32 * 1024 * 1024, 16);
   agg = VG_(malloc)("bm.agg", sizeof(Agg) * agg_cap);
   for (ULong i = 0; i < agg_cap; i++) agg[i].key = ~0ULL;
   sbuf = VG_(malloc)("bm.sbuf", 8 * SBUF_CAP);
   fd_samples = open_out("samples.bin");
   fd_events = open_out("events.tsv");
   ev("config\tsample\t%lld\n", clo_sample);
   for (Int m = 0; m < n_marks; m++) ev("mark\t%s\t%s\t%c\n", marks[m].name, stage_names[marks[m].stage], marks[m].extent ? 'e' : 's');
}

static void bm_fini(Int exitcode) {
   flush_samples();
   VG_(close)(fd_samples);
   for (Int t = 0; t < MAX_TIDS; t++)
      if (ts[t].sp_max) ev("thread_sp\t%d\t%llx\t%llx\n", t, (ULong)ts[t].sp_min, (ULong)ts[t].sp_max);
   for (Int s = 0; s < n_stages; s++) {
      ev("stage_total\t%s", stage_names[s]);
      for (Int k = 0; k < 8; k++) ev("\t%llu", stage_level[s][k]);
      ev("\t%llu\n", stage_wb[s]);
   }
   ev("totals\taccesses\t%llu\tinstructions\t%llu\tsamples\t%llu\twb_to_mem\t%llu\texit\t%d\n",
      n_access, n_instr, n_samples, wb_to_mem, exitcode);
   VG_(close)(fd_events);
   Int fd = open_out("agg.tsv");
   HChar b[512];
   for (ULong i = 0; i < agg_cap; i++) {
      Agg *a = &agg[i];
      if (a->key == ~0ULL) continue;
      Int n = VG_(snprintf)(b, sizeof b, "%s\t%llx", stage_names[a->key >> 48], (a->key & 0xFFFFFFFFFFFFULL) << 16);
      for (Int k = 0; k < 8; k++) n += VG_(snprintf)(b + n, sizeof b - n, "\t%llu", a->n[k]);
      b[n++] = '\n';
      VG_(write)(fd, b, n);
   }
   VG_(close)(fd);
}

static void bm_pre_clo_init(void) {
   VG_(details_name)("bytemove");
   VG_(details_version)("0.1");
   VG_(details_description)("which cache level serves each access");
   VG_(details_copyright_author)("goose research run, 2026");
   VG_(details_bug_reports_to)("-");
   VG_(details_avg_translation_sizeB)(400);
   VG_(basic_tool_funcs)(bm_post_clo_init, bm_instrument, bm_fini);
   VG_(needs_command_line_options)(bm_process_cmd_line_option, bm_print_usage, bm_print_debug_usage);
   VG_(track_new_mem_mmap)(on_mmap);
   VG_(track_die_mem_munmap)(on_munmap);
   VG_(track_new_mem_brk)(on_brk);
   VG_(track_new_mem_startup)(on_startup);
}

VG_DETERMINE_INTERFACE_VERSION(bm_pre_clo_init)

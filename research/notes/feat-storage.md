# feat-storage: storage and references in selfhost/

Branch `feat-storage`. Area: variable and limited arrays, nonfixed struct fields, root structs,
relative and optional references, globals without initializers, whole resizable assignment.

## Layout chosen (src/'s, docs/reference.md §4, §5, §8)

- `T[..k]` is fixed: a packed C struct `{ uintN_t len; T e[k]; }`, `N` the smallest width holding
  `k` (as src/ emits).
- Every variable-size value (`T[]`, `T[u8|u16|u32|u64|varint]`, `T[..]`, a struct with a variable
  field, `varint`) is a `uint8_t *` to its packed bytes, built by appending to a data stack:
  `[len][elements]`, `[u32 cap][u32 len][elements]`, fields in order; varint fields zigzag LEB128,
  varint lengths unsigned LEB128. A reference to one is the same pointer.
- Sizes are found by walking (`gg_size_<ty>`, `gg_span_<ty>` for n consecutive values, `gg_at_<ty>`
  for the k-th field of a variable struct), as src/'s `gs_size_*` do.
- A variable local owns a data-stack slot like a resizable one; a variable result is appended to
  the caller's destination stack (`gg_reference` with only `.stack` used), so `let t = make();`
  builds in place. Temporaries take a fresh slot reset to empty.
- Sequential arrays (variable elements) iterate with a cursor advanced by the element's size.
- Optionals: a reference whose null is 0 (a fat reference's header). Narrowing is a flow state:
  a persistent linked list in `ctx.edges` of checked path nodes known non-null; a branch saves a
  list head (one i64), joins intersect, `.=` and callees that rebind globals kill facts. Keeping
  the state fixed-size is what lets it live in recursive checker frames (see below).
- Root structs: one data-stack slot per nonfixed field, its `gg_stack *` stored beside the field;
  each field is its own provenance root (a kind-6 pseudo-symbol), so shrinking one field does not
  invalidate references into another.
- Relative links: `T&<w>` a signed w-byte offset from the slot, `T&<w in pool>` an unsigned offset
  from the pool's base plus one; loads decode to the plain reference. Values holding self-relative
  links are pushed in place (slot first) and rendered by pointer (a `#define value (*pvalue)` body).

## Boards (selfhost scoreboard, this branch)

run 23 -> 134 of 776 (with master's other builders), reject 3 -> 228 of 2036, accepted (wrongly
compiled error fixtures) back down from 457 to 340 by adding src/'s checks and wording for
relative links, index_of, root owners, constant sizes, outliving stores and shrinks.
Not done in this area: resizable struct tails (`struct S { ..., xs: T[>..] }`), whole resizable
assignment, varint relative links, `self` initializers, slice_pool's runtime natives, writability
provenance ("non-writable provenance").

## What Goose made easy, forced, or could not express (while writing the compiler in Goose)

- Forced: a `var s = "literal";` slice later rebound to text owned by `ctx` is rejected
  ("re-binding with a reference rooted at a different scope depth"). Fix: start it as
  `save_text(ctx, "")` so both roots agree. Three times in this work.
- Forced: a temporary `str(...)` built inside the argument list of a call into a recursive cycle
  is rejected (§7.8); hoist it into a `let` first. Twice.
- The selfhost's own checker (stricter than src/) rejected `c_build -> c_call(dest)` where `dest`
  is a different function's by-value parameter holding views ("recursive arguments broaden
  reference provenance"); routing the call through `c_into` (whose `dest` already reaches
  `c_call`) satisfies it. A limitation of selfhost's checker, not of Goose.
- Forced, and good: a recursive checker cannot keep a nonfixed local (a list of facts) across its
  recursive calls, so the narrowing state became an arena list addressed by one i64 — cheaper to
  save and restore than a copied set, and exactly SHAPES.md's "compact ids into an arena".
- Forced: storing a view into a field of `ctx` (`ctx.shrink_verb = save_text(...)`) is rejected as
  outliving its owner; store a token id instead and spell it at the error.
- Could not express: two diagnostic lines from one `error_at` (it exits); added `error_note`.

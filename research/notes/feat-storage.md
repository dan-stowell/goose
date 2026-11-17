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

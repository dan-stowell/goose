# feat-enums: notes from writing enums, match and friends in selfhost/

What Goose made easy, forced, or could not express while writing the compiler.

## Enums and match (2026-11-17)

- **Representation.** An enum is `T_ENUM` (its `first` lists variant types); a variant type is an
  ordinary `T_STRUCT` whose `element` is its enum and `count` its tag. Reusing the struct kind meant
  member access, construction, defaults, equality and rendering of payloads came for free. C layout
  matches the C++ compiler's: packed `{ uint8_t tag; union { V0 v0; ... } u; }`, payload-less
  variants take no union member.
- **Interning bit me.** `intern_type` keys on `kind/element/count/flags/decl`; storing the variant
  count in `count` after interning made every later lookup intern a *new* enum type. The count is
  now computed on demand. A Goose struct can't mark which fields form the key, so the key is
  implicit in one function; an explicit key struct would have caught this.
- **No multiple results** in the selfhost subset (the C++ compiler has them) pushed pattern
  intervals onto node fields (`bits`) and two accessor functions (`pattern_low`/`pattern_high`).
- **Recursive cycles may not hold non-fixed temporaries** (§7.8): `recursive fn pattern_text`
  returning `u8[>..]` and calling itself was rejected by the C++ compiler. Rewritten as a
  non-recursive pair returning views into the compiler's text arena. Likewise, coverage and
  duplicate checks in `check_match` use O(arms x patterns) scans of the node lists instead of a
  local growable array, because `check_match` is in the checker's recursive cycle and a non-fixed
  local there is an error ("call into a recursive cycle while nonfixed local is in scope"). The
  memory model shapes the algorithm: arenas outside the recursion, scans instead of scratch sets.
- **Results generic over constness** (§9.5) was missing from the checker: `fn f() -> u8[:]
  { "lit" }` failed. `check_return` now accepts the const twin and records a read-only result.

## Custom formatting dispatch (2026-11-17)

- A user `fn format(out: u8[>..]&, v: T)` is chosen once per type (`Type.formatter`) while checking
  a print/str/format argument, for every type reachable from it; generic overloads are specialized
  through the ordinary signature path with a synthesized call whose arguments are pre-annotated
  values (flag 512), so no new inference code was needed.
- The generated `gg_render_<ty>` helpers have no frame, but an overload needs a data-stack base.
  Rather than add a base parameter to every helper (more C bytes everywhere), a C global
  `gg_render_base` is set before a structural render, only in programs that have an overload; the
  overload call saves and restores it. A top-level argument calls its overload directly, passing
  the argument as a call would (a reference to its real storage).

## Break with a value (2026-11-17)

- The breaks of a `loop`/`block` join on the target node (its `b` remembers the last joined break).
  The emitter's control stack needed each target's destination, but a `CValue` holds views, and
  storing views in a container inside a recursive cycle is forbidden (§7.8: "references may only be
  passed down, not stored"). The destination is parked as offsets into the text arena instead
  (`park_control`/`control_destination`): integers in the container, views rebuilt on use. Same
  lesson as above: inside recursion, containers hold indices, never views.
- A `for` loop's input is evaluated before the loop catches breaks, in both checker and emitter.

## Case functions, variable-mode enums, float text (2026-11-17)

- Tag dispatch (§8.2) is tried when no overload takes the enum argument as is; each case is checked
  as a call whose dispatched argument is a synthesized payload value. The emitter evaluates every
  argument once, then switches on the tag.
- Variable mode (`E..`) is a second T_ENUM (flags 1, element = the fixed E) sharing E's variants;
  its value is a `uint8_t *` to `[tag][payload packed]`, fitting the storage builder's variable-size
  machinery (`gg_size_`, data-stack builds). `c_tag`/`c_payload` hide the two layouts from match,
  dispatch, equality and rendering. An empty payload `V {}` takes no bytes behind the tag.
- Float text (§3.7) was the last difference on several enum fixtures: shortest round-trip digits
  (an f32's own), `%g` layout at max(15, digits), `.0` on whole numbers, nan/inf spelled out.

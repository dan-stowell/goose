// Semantic checking is separate from emission. This is an experimental
// bootstrap checker; the fixture's scope is described in README.md.
// Keep these builtin IDs distinct from negative IDs used by dispatch.
const BI_CHECK_LENGTH = -140;
const BI_RANGE_INDEX = -141;
const BI_MOVE_FROM = -143;
const BI_INDEX_OF = -144;
const BI_BYTES_OF = -145;
const BI_FREE = -146;
const BI_ALLOC_INDEX = -147;
const BI_ALLOC_REF = -148;
const BI_ALLOC_SLICE = -149;
const BI_FREE_SLICE = -150;
const BI_REALLOC_SLICE = -151;

struct Value {
    ty: i64 = 0,
    root: i64 = -1,
    place: i64 = -1,
    readonly: bool = false,
    growshrink: bool = false,
    inexact: bool = false,
    known: bool = false,
    // A known integer stands for bits, and for alt where several constants
    // join (6.4): every value it stands for lies between the two. A single
    // constant keeps alt 0, which fits every integer type.
    bits: u64 = 0,
    alt: u64 = 0,
    held: i64 = -1,
    fields: i64 = -1,
}
struct Specialization {
    symbol: i64,
    body: i64,
    scope: i64,
    result: i64,
    state: i64 = 0,
    // Each result descriptor stores its type and provenance; flag 1 marks a
    // checked return and flag 2 a recursive caller using that provenance.
    results: i64 = -1,
    parameters: i64 = -1,
    shrinks: i64 = -1,
    caller: i64 = -1,
    in_cycle: bool = false,
    visit: i64 = 0,
    cycle_index: i64 = -1,
    cycle_low: i64 = 0,
    cycle_open: bool = false,
    cycle: i64 = -1,
    rebinds: i64 = -1,
}
struct CheckedCall { node: i64, scope: i64, callee: i64 }
// The root can own an aggregate, so its type cannot recover the element
// type of the particular array a propagated effect shrinks.
struct Shrink { root: i64, element: i64, balanced: bool }

// The pseudo-symbol naming one field's storage of a root owner (kind 6).
fn root_component(ctx: Compiler&, owner: i64, f: i64) -> i64 {
    var i = ctx.symbols.len;
    while i > owner { i--; if ctx.symbols[i].kind == 6 && ctx.symbols[i].root == owner && ctx.symbols[i].decl == f { return i; } }
    let id = ctx.symbols.len;
    ctx.symbols.push(Symbol { token: ctx.symbols[owner].token, ns: -1, kind: 6, decl: f, scope: ctx.symbols[owner].scope, ty: ctx.fielddefs[f].ty, state: 2, root: owner });
    index_symbol(ctx, id);
    return id;
}
fn value_of(ctx: Compiler&, n: i64) -> Value {
    let x = ctx.nodes[n];
    return Value { ty: x.ty, root: x.root, place: x.place, readonly: x.readonly, growshrink: x.growshrink, inexact: x.inexact, known: x.known, bits: x.bits, alt: x.alt, held: x.held, fields: x.fields };
}
fn annotate(ctx: Compiler&, n: i64, v: Value) -> Value {
    ctx.nodes[n].ty = v.ty; ctx.nodes[n].root = v.root; ctx.nodes[n].place = v.place;
    ctx.nodes[n].readonly = v.readonly; ctx.nodes[n].known = v.known; ctx.nodes[n].bits = v.bits; ctx.nodes[n].alt = v.alt;
    ctx.nodes[n].held = v.held;
    ctx.nodes[n].fields = v.fields;
    ctx.nodes[n].growshrink = v.growshrink;
    ctx.nodes[n].inexact = v.inexact;
    return v;
}
fn decay(ctx: Compiler&, v: Value) -> Value {
    var r = v;
    // An optional is not transparent: it decays only once narrowed.
    if r.ty >= 0 && ctx.types[r.ty].kind == T_REFERENCE && ctx.types[r.ty].flags & 4 == 0 { r.ty = ctx.types[r.ty].element; }
    return r;
}
fn numeric(ctx: Compiler&, ty: i64) -> bool { return ctx.types[ty].kind == T_INTEGER || ctx.types[ty].kind == T_FLOAT; }
fn boolean_type(ctx: Compiler&) -> i64 { return builtin_type(ctx, "bool"); }
fn default_integer(ctx: Compiler&) -> i64 { return integer_type(ctx, 8, false); }
fn root_depth(ctx: Compiler&, root: i64) -> i64 {
    if root < 0 { return 0; }
    return ctx.scopes[ctx.symbols[root].scope].depth;
}
fn root_outlives(ctx: Compiler&, source: i64, bound: i64) -> bool {
    if source < 0 || source == bound { return true; }
    if bound < 0 { return false; }
    return scope_contains(ctx, ctx.symbols[source].scope, ctx.symbols[bound].scope);
}
recursive fn contains_view(ctx: Compiler&, ty: i64) -> bool {
    let t = ctx.types[ty];
    if t.kind == T_REFERENCE || t.kind == T_SLICE { return true; }
    if t.kind == T_ARRAY { return contains_view(ctx, t.element); }
    if t.kind == T_STRUCT {
        var e = t.first;
        while e >= 0 { if contains_view(ctx, ctx.fielddefs[ctx.edges[e].value].ty) { return true; } e = ctx.edges[e].next; }
    }
    if t.kind == T_ENUM {
        var e = t.first;
        while e >= 0 { if contains_view(ctx, ctx.edges[e].value) { return true; } e = ctx.edges[e].next; }
    }
    return false;
}
fn store_lifetime(ctx: Compiler&, v: Value, destination: i64, token: i64) {
    let root = content_root(ctx, v);
    if contains_view(ctx, v.ty) && root_depth(ctx, root) > root_depth(ctx, destination) { error_at(ctx, token, "stored reference would outlive its owner"); }
    if destination >= 0 && root_depth(ctx, root) >= root_depth(ctx, ctx.symbols[destination].held) { ctx.symbols[destination].held = root; }
}
fn content_root(ctx: Compiler&, v: Value) -> i64 {
    if ctx.types[v.ty].kind == T_REFERENCE || ctx.types[v.ty].kind == T_SLICE { return v.root; }
    return v.held;
}
fn received(ctx: Compiler&, v: Value, target: i64) -> Value {
    var result = v; result.ty = target; return result;
}
fn scope_contains(ctx: Compiler&, outer: i64, inner: i64) -> bool {
    var s = inner;
    while s >= 0 { if s == outer { return true; } s = ctx.scopes[s].parent; }
    return false;
}
fn holds_view_of(ctx: Compiler&, ty: i64, element: i64) -> bool {
    ctx.visit++;
    return holds_view_walk(ctx, ty, element, ctx.visit);
}
recursive fn holds_view_walk(ctx: Compiler&, ty: i64, element: i64, visit: i64) -> bool {
    if ctx.types[ty].view_visit == visit { return false; }
    ctx.types[ty].view_visit = visit;
    let t = ctx.types[ty];
    if t.kind == T_SLICE { return t.element == element; }
    if t.kind == T_REFERENCE { return t.element == element || ((ctx.types[t.element].kind == T_STRUCT || ctx.types[t.element].kind == T_ENUM) && holds_view_walk(ctx, t.element, element, visit)); }
    if t.kind == T_ARRAY { return holds_view_walk(ctx, t.element, element, visit); }
    if t.kind == T_STRUCT {
        var e = t.first;
        while e >= 0 { if holds_view_walk(ctx, ctx.fielddefs[ctx.edges[e].value].ty, element, visit) { return true; } e = ctx.edges[e].next; }
    }
    if t.kind == T_ENUM {
        var e = t.first;
        while e >= 0 { if holds_view_walk(ctx, ctx.edges[e].value, element, visit) { return true; } e = ctx.edges[e].next; }
    }
    return false;
}
fn check_stored_view(ctx: Compiler&, v: Value, token: i64) {
    if v.growshrink { error_at(ctx, token, "a value that may refer into a grow-shrink array cannot be stored in a container"); }
    let root = content_root(ctx, v);
    if root >= 0 && contains_view(ctx, v.ty) {
        let t = ctx.types[decay(ctx, Value { ty: ctx.symbols[root].ty }).ty];
        if t.kind == T_ARRAY && t.flags == 4 && holds_view_of(ctx, v.ty, t.element) { error_at(ctx, token, "a reference into a grow-shrink array cannot be stored in a container"); }
    }
}
fn store_in_array(ctx: Compiler&, value: Value, array: Value, scope: i64, token: i64) {
    check_stored_view(ctx, value, token);
    store_lifetime(ctx, value, array.root, token);
    if array.inexact && contains_view(ctx, value.ty) {
        // A borrowed field's bound is not an identity guarantee. A reference
        // parameter to an array of the same shape can reach that storage too.
        for s in ctx.symbols {
            if s.kind == 2 && s.decl >= 0 && ctx.nodes[s.decl].tag == N_PARAM && s.ty >= 0 && scope_contains(ctx, s.scope, scope) && ctx.types[s.ty].kind == T_REFERENCE && ctx.types[s.ty].element == array.ty {
                store_lifetime(ctx, value, s.root, token);
            }
        }
    }
}
// Existing typed views remain conservatively live to scope exit. Byte views
// also invalidate on shrink, but a finished local read need not pin storage.
// Keep captured/global values live: a later call can read them indirectly.
fn byte_view_live(ctx: Compiler&, symbol: Symbol, token: i64) -> bool {
    if ctx.loop_depth > 0 || symbol.scope == 0 || ctx.scopes[symbol.scope].function != ctx.checking_function { return true; }
    for nested in ctx.symbols {
        if nested.kind == 3 && nested.scope > 0 && scope_contains(ctx, symbol.scope, nested.scope) { return true; }
    }
    for t, i in ctx.tokens {
        if i > token && t.file == ctx.tokens[symbol.token].file && t.text == ctx.tokens[symbol.token].text { return true; }
    }
    return false;
}
fn check_shrink(ctx: Compiler&, root: i64, element: i64, scope: i64, token: i64, balanced: bool, at_call: bool) {
    if root < 0 { error_at(ctx, token, "not implemented yet: shrink through an unknown root"); }
    if ctx.symbols[root].flags & 4 != 0 { error_at(ctx, token, "cannot shrink reusable pool"); }
    for s in ctx.symbols {
        if balanced && at_call { continue; }
        if s.kind != 2 || s.state != 2 || s.ty < 0 || !scope_contains(ctx, s.scope, scope) { continue; }
        let shape = ctx.types[s.ty];
        let byte_live = ctx.symbols[root].byteviewed && byte_view_live(ctx, s, token);
        let typed_view = (shape.kind == T_SLICE || shape.kind == T_REFERENCE) && shape.element == element;
        let direct_view = (shape.kind == T_SLICE || shape.kind == T_REFERENCE) && (shape.element == element || byte_live);
        if (direct_view && s.root == root) || (s.held >= 0 && (((!typed_view || contains_view(ctx, shape.element)) && holds_view_of(ctx, s.ty, element)) || (byte_live && contains_view(ctx, s.ty))) && root_depth(ctx, s.held) >= root_depth(ctx, root)) {
            error_at(ctx, token, str("shrink may invalidate '", ctx.tokens[s.token].text, "'; this checker conservatively keeps views live to scope exit"));
        }
    }
    if ctx.checking_function >= 0 && ctx.scopes[ctx.symbols[root].scope].function != ctx.checking_function {
        var e = ctx.specializations[ctx.checking_function].shrinks;
        while e >= 0 {
            let effect = ctx.edges[e].value;
            if ctx.shrinks[effect].root == root && ctx.shrinks[effect].element == element {
                if !balanced && ctx.shrinks[effect].balanced { ctx.shrinks[effect].balanced = false; ctx.effect_revision++; }
                return;
            }
            e = ctx.edges[e].next;
        }
        let effect = ctx.shrinks.len; ctx.shrinks.push(Shrink { root: root, element: element, balanced: balanced });
        let id = ctx.edges.len; ctx.edges.push(Edge { value: effect, next: ctx.specializations[ctx.checking_function].shrinks });
        ctx.specializations[ctx.checking_function].shrinks = id;
        ctx.effect_revision++;
    }
}
fn shrink_array(ctx: Compiler&, array: Value, scope: i64, token: i64, balanced: bool) {
    if array.root >= 0 && ctx.symbols[array.root].flags & 4 != 0 { error_at(ctx, token, "cannot shrink reusable pool"); }
    if ctx.types[array.ty].flags == 2 { return; }
    let element = element_type(ctx, array.ty);
    check_shrink(ctx, array.root, element, scope, token, balanced, false);
    if array.inexact {
        // A merged root is an outlives bound, not a unique storage identity.
        // Keep effects for every compatible owned array inside that bound.
        let limit = ctx.symbols.len;
        for i in limit {
            let owner = ctx.symbols[i];
            if i != array.root && owner.kind == 2 && owner.ty == array.ty && root_depth(ctx, i) <= root_depth(ctx, array.root) {
                check_shrink(ctx, i, element, scope, token, balanced, false);
            }
        }
    }
}
fn integer_fits(ctx: Compiler&, bits: u64, ty: i64) -> bool {
    let t = ctx.types[ty];
    if t.flags & 2 != 0 {
        if t.bytes == 8 { return true; }
        return bits < (1 as u64) << (t.bytes * 8);
    }
    let signed = bits as! i64;
    if t.bytes == 8 { return true; }
    let bound = 1 << (t.bytes * 8 - 1);
    return signed >= -bound && signed < bound;
}
fn constant_fits(ctx: Compiler&, a: Type, bits: u64, b: Type, target: i64) -> bool {
    if a.flags & 2 == 0 && (bits as! i64) < 0 && b.flags & 2 != 0 { return false; }
    if a.flags & 2 != 0 && bits > 9223372036854775807 && b.flags & 2 == 0 { return false; }
    return integer_fits(ctx, bits, target);
}
// The smaller and the larger of two constants of one integer type.
fn constant_low(ctx: Compiler&, ty: i64, x: u64, y: u64) -> u64 {
    if ctx.types[ty].flags & 2 != 0 { return if x < y { x } else { y }; }
    return if (x as! i64) < (y as! i64) { x } else { y };
}
fn constant_high(ctx: Compiler&, ty: i64, x: u64, y: u64) -> u64 {
    if ctx.types[ty].flags & 2 != 0 { return if x < y { y } else { x }; }
    return if (x as! i64) < (y as! i64) { y } else { x };
}
fn fits(ctx: Compiler&, v: Value, target: i64) -> bool {
    if target == v.ty || ctx.types[v.ty].kind == T_BOTTOM { return true; }
    let a = ctx.types[v.ty]; let b = ctx.types[target];
    if a.kind == T_NULL { return b.kind == T_REFERENCE && b.flags & 4 != 0; }
    // A reference fits an optional; an optional fits only an optional.
    if b.kind == T_REFERENCE && a.kind == T_REFERENCE && a.element == b.element && (a.flags & 4 == 0 || b.flags & 4 != 0) && (!v.readonly || b.flags & 1 != 0) { return true; }
    if b.kind == T_REFERENCE { return v.place >= 0 && decay(ctx, v).ty == b.element && (!v.readonly || b.flags & 1 != 0); }
    if a.kind == T_REFERENCE { return fits_plain(ctx, decay(ctx, v), target); }
    return fits_plain(ctx, v, target);
}
fn fits_plain(ctx: Compiler&, v: Value, target: i64) -> bool {
    let a = ctx.types[v.ty]; let b = ctx.types[target];
    if v.ty == target { return true; }
    // A variant value constructs its enum; the tag is static.
    if adapts_enum(ctx, v.ty, target) { return true; }
    if a.kind == T_INTEGER && b.kind == T_INTEGER {
        if v.known { return constant_fits(ctx, a, v.bits, b, target) && constant_fits(ctx, a, v.alt, b, target); }
        return (a.flags & 2 == b.flags & 2 && a.bytes <= b.bytes) || (a.flags & 2 != 0 && b.flags & 2 == 0 && a.bytes < b.bytes);
    }
    if a.kind == T_FLOAT && b.kind == T_FLOAT { return a.bytes <= b.bytes || v.known; }
    // Every integer becomes a float implicitly, rounding to the nearest (§6.3).
    if a.kind == T_INTEGER && b.kind == T_FLOAT { return true; }
    if a.kind == T_INTEGER && b.kind == T_VARINT { return a.flags & 2 == 0 || a.bytes < 8; }
    if (a.kind == T_ARRAY || a.kind == T_SLICE) && (b.kind == T_ARRAY || b.kind == T_SLICE) && a.element == b.element {
        if b.kind == T_SLICE { return !v.readonly || b.flags & 1 != 0; }
        if b.flags == 0 { return a.kind == T_ARRAY && a.flags == 0 && a.count == b.count; }
        return true;
    }
    return false;
}
// Parameters and results are generic over constness: a parameter declared
// u8[:] or T& takes a read-only argument too, and the specialization is
// checked with the argument's constness. An extern's parameters are C's,
// with exactly the constness they declare.
fn parameter_destination(ctx: Compiler&, ty: i64, external: bool) -> i64 {
    let t = ctx.types[ty];
    if external || t.flags & 1 != 0 { return ty; }
    if t.kind == T_SLICE { return slice_type(ctx, t.element, true); }
    if t.kind == T_REFERENCE { return reference_type(ctx, t.element, true); }
    return ty;
}
fn require_fit(ctx: Compiler&, n: i64, v: Value, target: i64) {
    if !fits(ctx, v, plain_reference(ctx, target)) {
        var text: u8[>..] = [];
        text.append("incompatible types: "); type_text(ctx, v.ty, text);
        if v.readonly && ctx.types[v.ty].kind != T_REFERENCE && ctx.types[v.ty].kind != T_SLICE { text.append(" (read-only)"); }
        text.append(" -> "); type_text(ctx, target, text);
        error_at(ctx, ctx.nodes[n].token, text);
    }
    ctx.nodes[n].target = target;
}
fn merge_numeric(ctx: Compiler&, a: Value, b: Value, token: i64) -> i64 {
    if !numeric(ctx, a.ty) || !numeric(ctx, b.ty) { error_at(ctx, token, "numeric operands required"); }
    if a.ty == b.ty { return a.ty; }
    // An integer meeting a float becomes that float, a literal or not.
    if ctx.types[a.ty].kind == T_INTEGER && ctx.types[b.ty].kind == T_FLOAT { return b.ty; }
    if ctx.types[a.ty].kind == T_FLOAT && ctx.types[b.ty].kind == T_INTEGER { return a.ty; }
    if a.known && !b.known { if !fits(ctx, a, b.ty) { error_at(ctx, token, "constant operand does not fit the other operand's type"); } return b.ty; }
    if b.known && !a.known { if !fits(ctx, b, a.ty) { error_at(ctx, token, "constant operand does not fit the other operand's type"); } return a.ty; }
    if fits(ctx, a, b.ty) { return b.ty; }
    if fits(ctx, b, a.ty) { return a.ty; }
    error_at(ctx, token, "numeric operands require an explicit conversion"); return 0;
}
recursive fn clone_tree(ctx: Compiler&, n: i64) -> i64 {
    if n < 0 { return -1; }
    let original = ctx.nodes[n];
    let id = node(ctx, original.tag, original.token);
    ctx.nodes[id] = original; ctx.nodes[id].first = -1; ctx.nodes[id].last = -1;
    // Only syntax edges are cloned. Tokens and namespace IDs are immutable.
    ctx.nodes[id].a = clone_tree(ctx, original.a);
    ctx.nodes[id].b = clone_tree(ctx, original.b);
    ctx.nodes[id].c = clone_tree(ctx, original.c);
    var e = original.first;
    while e >= 0 { child(ctx, id, clone_tree(ctx, ctx.edges[e].value)); e = ctx.edges[e].next; }
    return id;
}
fn first_child(ctx: Compiler&, n: i64) -> i64 {
    if n < 0 || ctx.nodes[n].first < 0 { return -1; }
    return ctx.edges[ctx.nodes[n].first].value;
}
fn child_count(ctx: Compiler&, n: i64) -> i64 {
    if n < 0 { return 0; }
    var count = 0; var e = ctx.nodes[n].first;
    while e >= 0 { count++; e = ctx.edges[e].next; }
    return count;
}

// Constant operands fold as the operation would compute them in 64 bits;
// whether the result fits its destination is checked where it lands.
fn fold_integer(ctx: Compiler&, op: const u8[:], a: u64, b: u64, signed: bool, token: i64) -> u64 {
    if op == "+" { return a + b; }
    if op == "-" { return a - b; }
    if op == "*" { return a * b; }
    if op == "/" || op == "%" {
        if b == 0 { error_at(ctx, token, "zero divisor in constant"); }
        if signed {
            let x = a as! i64; let y = b as! i64;
            if y == -1 { if op == "/" { return 0 - a; } return 0; }
            if op == "/" { return (x / y) as! u64; } return (x % y) as! u64;
        }
        if op == "/" { return a / b; } return a % b;
    }
    if op == "<<" { if b >= 64 { return 0; } return a << b; }
    if op == ">>" {
        if signed { let x = a as! i64; if b >= 64 { return if x < 0 { 0 - (1 as u64) } else { 0 }; } return (x >> (b as i64)) as! u64; }
        if b >= 64 { return 0; } return a >> b;
    }
    if op == "&" { return a & b; }
    if op == "|" { return a | b; }
    if op == "^" { return a ^ b; }
    return 0;
}
// A named constant (a global let or const with no written type bound to an
// integer constant, 3.1) and an untyped let bound to a literal-like float,
// local or global (6.3), adapt at each use as their initializer would.
fn adapts_as_constant(ctx: Compiler&, s: i64) -> bool {
    let symbol = ctx.symbols[s];
    if !symbol.known || symbol.kind != 2 || symbol.flags & 1 != 0 || symbol.decl < 0 { return false; }
    let decl = ctx.nodes[symbol.decl];
    if decl.tag != N_BIND || decl.a >= 0 { return false; }
    return symbol.scope == 0 || ctx.types[symbol.ty].kind == T_FLOAT;
}
recursive fn check_expression(ctx: Compiler&, n: i64, scope: i64, expected: i64) -> Value {
    let x = ctx.nodes[n];
    let tag = x.tag;
    var v = Value {};
    if tag == N_INT { v.ty = default_integer(ctx); v.known = true; v.bits = ctx.tokens[x.token].integer; if v.bits > 9223372036854775807 { v.ty = integer_type(ctx, 8, true); } }
    else if tag == N_FLOAT { v.ty = builtin_type(ctx, "f64"); v.known = true; }
    else if tag == N_NULL { v.ty = intern_type(ctx, Type { kind: T_NULL }); }
    else if tag == N_BOOL { v.ty = boolean_type(ctx); v.known = true; if ctx.tokens[x.token].text == "true" { v.bits = 1; } }
    else if tag == N_STRING { v.ty = slice_type(ctx, integer_type(ctx, 1, true), true); v.readonly = true; }
    else if tag == N_NAME {
        let s = lookup(ctx, n, scope, 2);
        if s < 0 { error_at(ctx, x.token, str("unknown variable '", ctx.tokens[x.token].text, "'")); }
        if ctx.symbols[s].state != 2 { error_at(ctx, x.token, "variable read before initialization"); }
        ctx.nodes[n].symbol = s;
        v.ty = ctx.symbols[s].ty; v.place = s; v.root = s;
        v.held = ctx.symbols[s].held;
        v.fields = ctx.symbols[s].fields;
        if ctx.types[v.ty].kind == T_REFERENCE || ctx.types[v.ty].kind == T_SLICE { v.root = ctx.symbols[s].root; }
        v.readonly = ctx.symbols[s].readonly || ctx.symbols[s].flags & 2 != 0 || (ctx.types[v.ty].kind == T_SLICE && ctx.types[v.ty].flags & 1 != 0) || (ctx.types[v.ty].kind == T_REFERENCE && ctx.types[v.ty].flags & 1 != 0);
        v.growshrink = ctx.symbols[s].growshrink;
        v.inexact = ctx.symbols[s].inexact;
        v.known = adapts_as_constant(ctx, s); v.bits = ctx.symbols[s].bits;
    } else if tag == N_UNARY {
        let operand = check_expression(ctx, x.a, scope, -1);
        let op = ctx.tokens[x.token].text;
        if op == "&" {
            if operand.place < 0 { error_at(ctx, x.token, "cannot take a reference to a temporary"); }
            v = operand; v.ty = reference_type(ctx, decay(ctx, operand).ty, operand.readonly);
        } else {
            v = decay(ctx, operand);
            if op == "!" && (is_optional(ctx, operand.ty) || is_optional(ctx, slot_type(ctx, x.a))) { ctx.nodes[x.a].truth = true; v = Value { ty: boolean_type(ctx) }; }
            else if op == "!" { if v.ty != boolean_type(ctx) { error_at(ctx, x.token, "boolean operand required"); } if v.known { v.bits = 0; if operand.bits == 0 { v.bits = 1; } } }
            else if op == "-" || op == "~" {
                if !numeric(ctx, v.ty) { error_at(ctx, x.token, "numeric operand required"); }
                if op == "-" && ctx.nodes[x.a].tag == N_INT && ctx.tokens[ctx.nodes[x.a].token].integer > 9223372036854775808 { error_at(ctx, x.token, "negated literal too large for i64"); }
                if op == "-" && ctx.types[v.ty].kind == T_INTEGER && ctx.types[v.ty].flags & 2 != 0 && v.bits != 9223372036854775808 { error_at(ctx, x.token, "cannot negate an unsigned value"); }
                if v.known && ctx.types[v.ty].kind == T_INTEGER {
                    if op == "-" { v.bits = 0 - v.bits; v.alt = 0 - v.alt; v.ty = default_integer(ctx); }
                    else { v.bits = ~v.bits; if v.alt != 0 { v.alt = ~v.alt; } }
                }
                v.place = -1;
            }
        }
    } else if tag == N_BINARY && (ctx.tokens[x.token].text == "&&" || ctx.tokens[x.token].text == "||") {
        require_condition(ctx, x.a, check_expression(ctx, x.a, scope, -1));
        let before = ctx.flow;
        ctx.flow = condition_facts(ctx, x.a, ctx.tokens[x.token].text == "&&", before);
        require_condition(ctx, x.b, check_expression(ctx, x.b, scope, -1));
        ctx.flow = before;
        v.ty = boolean_type(ctx);
    } else if tag == N_BINARY && (ctx.tokens[x.token].text == "==" || ctx.tokens[x.token].text == "!=") && (ctx.nodes[x.a].tag == N_NULL || ctx.nodes[x.b].tag == N_NULL) {
        // A null test compares a reference's address.
        var other = x.a; var empty = x.b;
        if ctx.nodes[x.a].tag == N_NULL { other = x.b; empty = x.a; }
        let o = check_expression(ctx, other, scope, -1); check_expression(ctx, empty, scope, -1);
        var slot = o.ty;
        if ctx.types[slot].kind != T_REFERENCE { slot = slot_type(ctx, other); }
        if slot < 0 || ctx.types[slot].kind != T_REFERENCE { error_at(ctx, x.token, "only a reference or optional compares with null"); }
        ctx.nodes[other].target = slot; ctx.nodes[empty].target = slot;
        v.ty = boolean_type(ctx);
    } else if tag == N_BINARY {
        let a = decay(ctx, check_expression(ctx, x.a, scope, -1));
        let b = decay(ctx, check_expression(ctx, x.b, scope, -1));
        let op = ctx.tokens[x.token].text;
        if op == "&&" || op == "||" { require_fit(ctx, x.a, a, boolean_type(ctx)); require_fit(ctx, x.b, b, boolean_type(ctx)); v.ty = boolean_type(ctx); }
        else if op == "==" || op == "!=" {
            if numeric(ctx, a.ty) && numeric(ctx, b.ty) { let common = merge_numeric(ctx, a, b, x.token); require_fit(ctx, x.a, a, common); require_fit(ctx, x.b, b, common); }
            else if a.ty != b.ty && !(element_type(ctx, a.ty) >= 0 && element_type(ctx, a.ty) == element_type(ctx, b.ty)) { error_at(ctx, x.token, "equality operands have different types"); }
            v.ty = boolean_type(ctx);
        } else {
            var common = a.ty;
            if op != "<<" && op != ">>" { common = merge_numeric(ctx, a, b, x.token); }
            else if ctx.types[a.ty].kind != T_INTEGER || ctx.types[b.ty].kind != T_INTEGER { error_at(ctx, x.token, "integer shift operands required"); }
            require_fit(ctx, x.a, a, common);
            if op != "<<" && op != ">>" { require_fit(ctx, x.b, b, common); }
            v.ty = common;
            if a.known && b.known && ctx.types[common].kind == T_INTEGER && op != "<" && op != "<=" && op != ">" && op != ">=" {
                let signed = ctx.types[common].flags & 2 == 0;
                v.known = true; v.bits = fold_integer(ctx, op, a.bits, b.bits, signed, x.token);
                if a.alt != 0 || b.alt != 0 {
                    // A single constant's alt is 0 by convention: it stands for bits alone.
                    let aa = if a.alt == 0 { a.bits } else { a.alt }; let ba = if b.alt == 0 { b.bits } else { b.alt };
                    let p = fold_integer(ctx, op, aa, b.bits, signed, x.token); let q = fold_integer(ctx, op, a.bits, ba, signed, x.token); let r = fold_integer(ctx, op, aa, ba, signed, x.token);
                    let low = constant_low(ctx, common, constant_low(ctx, common, v.bits, p), constant_low(ctx, common, q, r));
                    let high = constant_high(ctx, common, constant_high(ctx, common, v.bits, p), constant_high(ctx, common, q, r));
                    v.bits = high; v.alt = low;
                }
            }
            if ctx.types[common].kind == T_FLOAT && (ctx.types[a.ty].kind != T_FLOAT || a.known) && (ctx.types[b.ty].kind != T_FLOAT || b.known) { v.known = true; }
            if op == "<" || op == "<=" || op == ">" || op == ">=" { v.ty = boolean_type(ctx); v.known = false; }
        }
    } else if tag == N_CAST {
        let a = decay(ctx, check_expression(ctx, x.a, scope, -1)); v.ty = resolve_type(ctx, x.b, scope);
        if !numeric(ctx, a.ty) || !numeric(ctx, v.ty) { error_at(ctx, x.token, "casts require numeric types"); }
        v.known = a.known; v.bits = a.bits;
        if ctx.types[a.ty].kind == T_FLOAT && ctx.types[v.ty].kind == T_INTEGER {
            if x.flags & 1 == 0 { error_at(ctx, x.token, "not implemented yet: range-checked float-to-integer conversion"); }
            // A float constant keeps no integer bits to fold.
            v.known = false; v.bits = 0;
        }
    } else if tag == N_MEMBER && variant_owner(ctx, x.a, scope) >= 0 {
        // A payload-less variant names a constant of its enum's type.
        let owner = variant_owner(ctx, x.a, scope);
        let vt = find_variant(ctx, owner, x.token);
        let spelled = ctx.tokens[ctx.nodes[ctx.types[owner].decl].token].text;
        if vt < 0 { error_at(ctx, x.token, str("enum ", spelled, " has no variant named ", ctx.tokens[x.token].text)); }
        if has_payload(ctx, vt) { error_at(ctx, x.token, str("variant ", spelled, ".", ctx.tokens[x.token].text, " has a payload; construct it with ", spelled, ".", ctx.tokens[x.token].text, " { ... }")); }
        ctx.nodes[n].symbol = vt; ctx.nodes[n].flags |= 1024; v.ty = if ctx.types[owner].fixed_ok { owner } else { varmode_type(ctx, owner) };
    } else if tag == N_MEMBER {
        let a = decay(ctx, check_expression(ctx, x.a, scope, -1));
        if element_type(ctx, a.ty) >= 0 && (ctx.tokens[x.token].text == "len" || ctx.tokens[x.token].text == "cap") {
            if ctx.tokens[x.token].text == "cap" && (ctx.types[a.ty].kind != T_ARRAY || ctx.types[a.ty].flags != 2) { error_at(ctx, x.token, "capacity exists only on limited arrays"); }
            v.ty = default_integer(ctx);
        } else {
            if ctx.types[a.ty].kind != T_STRUCT { error_at(ctx, x.token, "member access requires a struct"); }
            let f = find_field(ctx, a.ty, x.token);
            if f < 0 { error_at(ctx, x.token, "unknown field"); }
            ctx.nodes[n].symbol = f; v.ty = ctx.fielddefs[f].ty; v.root = a.root; v.place = a.place; v.readonly = a.readonly || ctx.fielddefs[f].flags & 2 != 0;
            // Each nonfixed field of a root owner is storage of its own.
            if ctx.types[a.ty].size_class == 3 && ctx.types[v.ty].size_class != 0 && a.root >= 0 { v.root = root_component(ctx, a.root, f); }
            // A varint field reads as an i64 and is written only at construction.
            if ctx.types[v.ty].kind == T_VARINT { v.ty = default_integer(ctx); v.place = -1; }
            // A relative link loads as the plain reference it encodes.
            if is_relative(ctx, v.ty) { v.ty = plain_reference(ctx, v.ty); }
            v.held = a.held;
            var initializer = a.fields;
            while initializer >= 0 {
                let field = ctx.edges[initializer].value;
                if ctx.nodes[field].symbol == f {
                    let stored = value_of(ctx, ctx.nodes[field].a);
                    v.fields = stored.fields;
                    if ctx.types[v.ty].kind == T_REFERENCE || ctx.types[v.ty].kind == T_SLICE { v.root = stored.root; v.held = stored.held; v.growshrink = stored.growshrink; }
                    break;
                }
                initializer = ctx.edges[initializer].next;
            }
            if ctx.types[v.ty].kind == T_REFERENCE || ctx.types[v.ty].kind == T_SLICE { if initializer < 0 { v.root = a.held; } v.readonly = ctx.types[v.ty].flags & 1 != 0; v.inexact = true; }
            if ctx.types[v.ty].kind == T_REFERENCE && v.root >= 0 { v.held = ctx.symbols[v.root].held; v.fields = ctx.symbols[v.root].fields; }
        }
    } else if tag == N_INDEX || tag == N_SLICE {
        let a = decay(ctx, check_expression(ctx, x.a, scope, -1)); let element = element_type(ctx, a.ty);
        if element < 0 { error_at(ctx, x.token, "indexing requires an array or slice"); }
        if ctx.types[element].size_class != 0 { error_at(ctx, x.token, "variable-size elements require sequential iteration"); }
        if x.b >= 0 { let b = decay(ctx, check_expression(ctx, x.b, scope, -1)); if ctx.types[b.ty].kind != T_INTEGER { error_at(ctx, x.token, "index must be an integer"); } }
        if x.c >= 0 { let c = decay(ctx, check_expression(ctx, x.c, scope, -1)); if ctx.types[c.ty].kind != T_INTEGER { error_at(ctx, x.token, "slice bound must be an integer"); } }
        v.ty = plain_reference(ctx, element); v.root = a.root; v.place = a.place; v.readonly = a.readonly;
        v.held = a.held;
        v.growshrink = a.growshrink;
        v.inexact = a.inexact;
        if tag == N_INDEX && (ctx.types[element].kind == T_REFERENCE || ctx.types[element].kind == T_SLICE) { v.root = a.held; v.inexact = true; }
        if tag == N_SLICE { v.ty = slice_type(ctx, element, a.readonly); v.place = -1; }
    } else if tag == N_ARRAY || tag == N_FILL || tag == N_LIMITED { v = check_array(ctx, n, scope, expected); }
    else if tag == N_CONSTRUCT { v = check_construct(ctx, n, scope); }
    else if tag == N_CALL { v = check_call(ctx, n, scope); }
    else if tag == N_RESULT { v = value_of(ctx, n); }
    else if tag == N_BLOCK { v = check_block(ctx, n, scope, expected); }
    else if tag == N_IF {
        require_condition(ctx, x.a, check_expression(ctx, x.a, scope, -1));
        let before = ctx.flow;
        ctx.flow = condition_facts(ctx, x.a, true, before);
        let a = check_expression(ctx, x.b, scope, expected);
        let after_then = ctx.flow;
        ctx.flow = condition_facts(ctx, x.a, false, before);
        var else_diverges = false;
        if x.c >= 0 { let b = check_expression(ctx, x.c, scope, expected); else_diverges = ctx.types[b.ty].kind == T_BOTTOM; v = join_branch(ctx, a, b, x.b, x.c, x.token); }
        if ctx.types[a.ty].kind == T_BOTTOM { }
        else if else_diverges { ctx.flow = after_then; }
        else { ctx.flow = fact_meet(ctx, after_then, ctx.flow); }
    } else if tag == N_MATCH { v = check_match(ctx, n, scope, expected); }
    else if tag == N_WHILE || tag == N_FOR || tag == N_LOOP || tag == N_EARLY { v = check_loop(ctx, n, scope, expected); }
    else if tag == N_RETURN {
        if ctx.checking_function < 0 { error_at(ctx, x.token, "return outside a function"); }
        if x.a >= 0 { error_at(ctx, x.token, "not implemented yet: long-distance returns"); }
        check_returns(ctx, n, scope);
        v.ty = intern_type(ctx, Type { kind: T_BOTTOM });
    } else if tag == N_BREAK || tag == N_CONTINUE {
        if ctx.loop_depth == 0 { error_at(ctx, x.token, "loop exit outside a loop or block"); }
        if tag == N_BREAK { ctx.loop_breaks++; }
        if x.first >= 0 {
            // The breaks of one loop or block agree on a type, joined on the
            // target node; its b is the break whose value was joined last.
            let target = ctx.break_target;
            if child_count(ctx, n) > 1 { error_at(ctx, x.token, "break takes one value"); }
            if target < 0 || (ctx.nodes[target].tag != N_LOOP && ctx.nodes[target].tag != N_EARLY) { error_at(ctx, x.token, "break with a value needs a loop or block target"); }
            let value = first_child(ctx, n);
            let previous = ctx.nodes[target].b;
            let b = check_expression(ctx, value, scope, ctx.nodes[target].c);
            check_branch_value(ctx, target, b, value, ctx.nodes[ctx.nodes[target].a].symbol, if ctx.nodes[target].tag == N_LOOP { "loop" } else { "block" }, ctx.nodes[target].c);
            if previous < 0 { var first = b; first.place = -1; first.known = false; annotate(ctx, target, first); }
            else {
                // The first break fixes the type; later ones adapt to it.
                let first = value_of(ctx, target);
                if ctx.types[first.ty].kind != T_BOTTOM && ctx.types[b.ty].kind != T_BOTTOM && !fits(ctx, b, first.ty) { type_mismatch(ctx, ctx.nodes[value].token, first.ty, b.ty); }
                annotate(ctx, target, join_branch(ctx, first, b, previous, value, x.token));
            }
            ctx.nodes[target].b = value;
        }
        v.ty = intern_type(ctx, Type { kind: T_BOTTOM });
    } else if tag == N_EXPR_STMT { let inner = check_expression(ctx, x.a, scope, -1); if ctx.types[inner.ty].kind == T_BOTTOM { v = inner; } }
    else if tag == N_BIND { check_binding(ctx, n, scope); }
    else if tag == N_ASSIGN { check_assignment(ctx, n, scope); }
    else if tag == N_FUNCTION {
        let s = ctx.nodes[n].symbol;
        ctx.symbols[s].state = 2; ctx.symbols[s].capture_limit = ctx.symbols.len;
    }
    else { error_at(ctx, x.token, str("not implemented yet: expression tag ", tag)); }
    let function_body = tag == N_BLOCK && ctx.checking_function >= 0 && ctx.specializations[ctx.checking_function].body == n;
    if (tag == N_IF || tag == N_BLOCK || tag == N_MATCH || tag == N_LOOP || tag == N_EARLY) && !function_body && v.ty != 0 && ctx.types[v.ty].kind != T_BOTTOM {
        if expected >= 0 && ctx.types[expected].kind == T_REFERENCE {
            require_fit(ctx, n, v, expected); v.ty = expected;
        } else {
            v = decay(ctx, v);
            if v.place >= 0 && ctx.types[v.ty].size_class > 0 { error_at(ctx, x.token, "nonfixed storage is not copied implicitly by a control expression; use copy or a reference destination"); }
        }
        v.place = -1;
    }
    if (tag == N_ARRAY || tag == N_FILL || tag == N_CONSTRUCT || tag == N_CALL || tag == N_IF || tag == N_MATCH || tag == N_LOOP || tag == N_EARLY || (tag == N_BLOCK && !function_body)) && (ctx.types[v.ty].kind == T_ARRAY || ctx.types[v.ty].kind == T_STRUCT || ctx.types[v.ty].kind == T_ENUM) && v.place < 0 {
        let temporary_scope = scope_new(ctx, scope, ctx.checking_function);
        let temporary_root = ctx.symbols.len;
        ctx.symbols.push(Symbol { token: x.token, ns: -1, kind: 4, decl: n, scope: temporary_scope, ty: v.ty, state: 2 });
        index_symbol(ctx, temporary_root);
        v.root = temporary_root;
        if tag != N_CALL || ctx.nodes[n].symbol == -27 { v.readonly = true; }
    }
    if contains_view(ctx, v.ty) && content_root(ctx, v) >= 0 {
        let owner = ctx.types[decay(ctx, Value { ty: ctx.symbols[content_root(ctx, v)].ty }).ty];
        if owner.kind == T_ARRAY && owner.flags == 4 && holds_view_of(ctx, v.ty, owner.element) { v.growshrink = true; }
    }
    if tag == N_NAME || tag == N_MEMBER || tag == N_INDEX { v = narrowed(ctx, n, v); }
    return annotate(ctx, n, v);
}

fn type_mismatch(ctx: Compiler&, token: i64, want: i64, got: i64) {
    var text: u8[>..] = [];
    text.append("expected a value of type "); type_text(ctx, want, text); text.append(", got "); type_text(ctx, got, text);
    error_at(ctx, token, text);
}
// A control expression's value leaves its branch: a nonfixed one names
// storage that is not copied implicitly, and a view may not outlive the
// scope the branch opened (a binder, a block's locals).
fn check_branch_value(ctx: Compiler&, construct: i64, v: Value, node: i64, inner: i64, what: const u8[:], expected: i64) {
    let d = decay(ctx, v);
    let referenced = expected >= 0 && ctx.types[expected].kind == T_REFERENCE;
    let tail = ctx.checking_function >= 0 && ctx.nodes[ctx.specializations[ctx.checking_function].body].a == construct;
    if !referenced && !tail && d.place >= 0 && ctx.types[d.ty].size_class > 0 && ctx.nodes[node].tag == N_NAME {
        error_at(ctx, ctx.nodes[node].token, str(ctx.tokens[ctx.nodes[node].token].text, " is not fixed-size and is not copied implicitly"));
    }
    let root = content_root(ctx, received(ctx, v, d.ty));
    if inner >= 0 && contains_view(ctx, d.ty) && root >= 0 && scope_contains(ctx, inner, ctx.symbols[root].scope) {
        error_at(ctx, ctx.nodes[node].token, str("the ", what, "'s value is ", if ctx.types[d.ty].kind == T_SLICE { "a slice" } else { "a reference" }, " rooted at ", ctx.tokens[ctx.symbols[root].token].text, ", which does not outlive it"));
    }
}
// Two branches of an if or match agree on a type, adapting a literal or a
// variant either way; the joined value is bounded by the shorter-lived root.
fn join_branch(ctx: Compiler&, a: Value, b: Value, anode: i64, bnode: i64, token: i64) -> Value {
    var v = a;
    if ctx.types[a.ty].kind == T_BOTTOM { v = b; }
    else if ctx.types[b.ty].kind != T_BOTTOM && a.ty != b.ty {
        if fits(ctx, b, a.ty) { require_fit(ctx, bnode, b, a.ty); }
        else if fits(ctx, a, b.ty) { v.ty = b.ty; require_fit(ctx, anode, a, b.ty); }
        else if a.ty == 0 || b.ty == 0 { v.ty = 0; }
        else { error_at(ctx, token, "branches have incompatible types"); }
    }
    if root_depth(ctx, b.root) > root_depth(ctx, v.root) { v.root = b.root; }
    if root_depth(ctx, b.held) > root_depth(ctx, v.held) { v.held = b.held; }
    if b.fields != v.fields { v.fields = -1; }
    v.readonly = a.readonly || b.readonly;
    v.growshrink = a.growshrink || b.growshrink;
    v.inexact = a.inexact || b.inexact || a.root != b.root;
    v.place = -1; v.known = false;
    // Constant branches join to a constant range of the common type.
    if a.known && b.known && ctx.types[a.ty].kind == ctx.types[b.ty].kind && (ctx.types[a.ty].kind == T_FLOAT || ctx.types[a.ty].kind == T_INTEGER) {
        v.known = true;
        if ctx.types[v.ty].kind == T_INTEGER {
            let low = constant_low(ctx, v.ty, constant_low(ctx, v.ty, a.bits, a.alt), constant_low(ctx, v.ty, b.bits, b.alt));
            let high = constant_high(ctx, v.ty, constant_high(ctx, v.ty, a.bits, a.alt), constant_high(ctx, v.ty, b.bits, b.alt));
            v.bits = high; v.alt = low;
        }
    }
    return v;
}
// Integer patterns order as unsigned keys: a u64's as they are, any other
// type's with the sign bit flipped. A pattern node's bits hold its value.
fn pattern_key(ctx: Compiler&, bits: u64, ty: i64) -> u64 {
    if ctx.types[ty].flags & 2 != 0 && ctx.types[ty].bytes == 8 { return bits; }
    return bits ^ 9223372036854775808;
}
fn pattern_low(ctx: Compiler&, item: i64, ty: i64) -> u64 {
    if ctx.nodes[item].tag == N_RANGE { return pattern_key(ctx, ctx.nodes[ctx.nodes[item].a].bits, ty); }
    return pattern_key(ctx, ctx.nodes[item].bits, ty);
}
fn pattern_high(ctx: Compiler&, item: i64, ty: i64) -> u64 {
    if ctx.nodes[item].tag == N_RANGE { return pattern_key(ctx, ctx.nodes[ctx.nodes[item].b].bits, ty) - 1; }
    return pattern_key(ctx, ctx.nodes[item].bits, ty);
}
fn bound_text(ctx: Compiler&, n: i64) -> const u8[:] {
    if ctx.nodes[n].tag == N_UNARY { return own_text(ctx, str("-", ctx.tokens[ctx.nodes[ctx.nodes[n].a].token].text)); }
    return ctx.tokens[ctx.nodes[n].token].text;
}
fn pattern_text(ctx: Compiler&, item: i64) -> const u8[:] {
    let x = ctx.nodes[item];
    if x.tag == N_RANGE { return own_text(ctx, str(bound_text(ctx, x.a), "..", bound_text(ctx, x.b))); }
    return bound_text(ctx, item);
}
recursive fn pattern_literal(ctx: Compiler&, item: i64) -> bool {
    let x = ctx.nodes[item];
    if x.tag == N_RANGE { return pattern_literal(ctx, x.a) && pattern_literal(ctx, x.b); }
    if x.tag == N_UNARY { return ctx.nodes[x.a].tag == N_INT; }
    return x.tag == N_INT;
}
// A literal or a let/const global, either one negated, at the scrutinee's type.
fn pattern_value(ctx: Compiler&, n: i64, scope: i64, ty: i64) -> u64 {
    var inner = n; if ctx.nodes[n].tag == N_UNARY { inner = ctx.nodes[n].a; }
    let spelled = ctx.tokens[ctx.nodes[inner].token].text;
    if ctx.nodes[inner].tag == N_NAME {
        let f = lookup(ctx, inner, scope, 3);
        if f >= 0 && ctx.symbols[f].scope != 0 { error_at(ctx, ctx.nodes[n].token, str("match pattern ", spelled, " names a nested function, not a constant")); }
        let tp = lookup(ctx, inner, scope, 1);
        if tp >= 0 && ctx.symbols[tp].decl < 0 { error_at(ctx, ctx.nodes[n].token, str("match pattern ", spelled, " names a type parameter, not a constant")); }
        let s = lookup(ctx, inner, scope, 2);
        if s < 0 { error_at(ctx, ctx.nodes[n].token, str("unknown constant ", spelled, " in an integer match")); }
        if ctx.symbols[s].scope != 0 { error_at(ctx, ctx.nodes[n].token, str("match pattern ", spelled, " names a local variable, not a constant")); }
        if ctx.symbols[s].flags & 1 != 0 { error_at(ctx, ctx.nodes[n].token, str("match pattern ", spelled, " names a var global, not a constant")); }
    }
    if ctx.nodes[n].tag == N_UNARY && ctx.nodes[inner].tag == N_INT && ctx.tokens[ctx.nodes[inner].token].integer > 9223372036854775808 { error_at(ctx, ctx.nodes[n].token, "negated literal too large for i64"); }
    let bits = constant_integer(ctx, n);
    let t = ctx.types[ty];
    var fit = integer_fits(ctx, bits, ty);
    if t.flags & 2 == 0 && ctx.nodes[n].tag != N_UNARY && ctx.nodes[n].tag == N_INT && bits > 9223372036854775807 { fit = false; }
    if t.flags & 2 != 0 && t.bytes < 8 && ctx.nodes[n].tag == N_UNARY && bits != 0 { fit = false; }
    if !fit { error_at(ctx, ctx.nodes[n].token, "match pattern does not fit the scrutinee type"); }
    ctx.nodes[n].bits = bits;
    return bits;
}
fn covered_by_earlier(ctx: Compiler&, m: i64, arm: i64, lo: u64, hi: u64, ty: i64) -> bool {
    // Walk forward from lo through the earlier arms' patterns until hi.
    var cursor = lo;
    loop {
        var reach = cursor; var found = false;
        var e = ctx.nodes[m].first;
        while e >= 0 && ctx.edges[e].value != arm {
            var p = ctx.nodes[ctx.edges[e].value].first;
            while p >= 0 {
                let item = ctx.edges[p].value;
                let a = pattern_low(ctx, item, ty); let b = pattern_high(ctx, item, ty);
                if a <= cursor && cursor <= b && b >= reach { reach = b; found = true; }
                p = ctx.edges[p].next;
            }
            e = ctx.edges[e].next;
        }
        if !found { return false; }
        if reach >= hi || reach == 18446744073709551615 { return true; }
        cursor = reach + 1;
    }
    return false;
}
recursive fn check_match(ctx: Compiler&, n: i64, scope: i64, expected: i64) -> Value {
    let x = ctx.nodes[n];
    let s = decay(ctx, check_expression(ctx, x.a, scope, -1));
    let st = ctx.types[s.ty];
    if st.kind != T_ENUM && st.kind != T_INTEGER { error_at(ctx, x.token, "cannot match on a value of this type"); }
    if x.first < 0 { error_at(ctx, x.token, "match has no arms"); }
    var e = x.first;
    var wildcard = false;
    while e >= 0 {
        let arm = ctx.edges[e].value;
        if wildcard { error_at(ctx, ctx.nodes[arm].token, "_ must be the last match arm"); }
        if ctx.nodes[arm].flags & 2 != 0 { wildcard = true; e = ctx.edges[e].next; continue; }
        var p = ctx.nodes[arm].first;
        while p >= 0 {
            let item = ctx.edges[p].value; let t = ctx.nodes[item].token;
            if st.kind == T_ENUM {
                if ctx.nodes[item].tag != N_NAME || ctx.nodes[item].flags & 1 != 0 { error_at(ctx, t, "ADT match arms are variant names (or _)"); }
                let vt = find_variant(ctx, s.ty, t);
                if vt < 0 { error_at(ctx, t, str("enum ", ctx.tokens[ctx.nodes[st.decl].token].text, " has no variant named ", ctx.tokens[t].text)); }
                ctx.nodes[item].symbol = vt;
                var q = x.first;
                while q != e {
                    var r = ctx.nodes[ctx.edges[q].value].first;
                    while r >= 0 { if ctx.nodes[ctx.edges[r].value].symbol == vt { error_at(ctx, t, str("variant ", ctx.tokens[t].text, " is already matched by an earlier arm")); } r = ctx.edges[r].next; }
                    q = ctx.edges[q].next;
                }
                var r = ctx.nodes[arm].first;
                while r != p { if ctx.nodes[ctx.edges[r].value].symbol == vt { error_at(ctx, t, str("variant ", ctx.tokens[t].text, " is listed twice")); } r = ctx.edges[r].next; }
            } else {
                if ctx.nodes[arm].b >= 0 { error_at(ctx, t, str("constant pattern ", pattern_text(ctx, item), " has no payload to bind")); }
                if ctx.nodes[item].tag == N_RANGE {
                    pattern_value(ctx, ctx.nodes[item].a, scope, s.ty); pattern_value(ctx, ctx.nodes[item].b, scope, s.ty);
                    if pattern_key(ctx, ctx.nodes[ctx.nodes[item].b].bits, s.ty) <= pattern_key(ctx, ctx.nodes[ctx.nodes[item].a].bits, s.ty) { error_at(ctx, t, "empty range in match pattern"); }
                } else { pattern_value(ctx, item, scope, s.ty); }
                let lo = pattern_low(ctx, item, s.ty); let hi = pattern_high(ctx, item, s.ty);
                if covered_by_earlier(ctx, n, arm, lo, hi, s.ty) { error_at(ctx, t, str("match pattern ", pattern_text(ctx, item), " never matches: earlier arms match all of its values")); }
                var r = ctx.nodes[arm].first;
                while r != p {
                    let other = ctx.edges[r].value;
                    if !(pattern_low(ctx, other, s.ty) > hi || lo > pattern_high(ctx, other, s.ty)) {
                        if pattern_text(ctx, item) == pattern_text(ctx, other) { error_at(ctx, t, str("match pattern ", pattern_text(ctx, item), " is listed twice")); }
                        if pattern_literal(ctx, item) && pattern_literal(ctx, other) { error_at(ctx, t, str("match patterns ", pattern_text(ctx, other), " and ", pattern_text(ctx, item), " overlap")); }
                    }
                    r = ctx.edges[r].next;
                }
            }
            p = ctx.edges[p].next;
        }
        e = ctx.edges[e].next;
    }
    if st.kind == T_INTEGER && !wildcard { error_at(ctx, x.token, "integer match requires a _ arm"); }
    if st.kind == T_ENUM && !wildcard {
        var v = st.first;
        while v >= 0 {
            let vt = ctx.edges[v].value; var covered = false;
            var q = x.first;
            while q >= 0 {
                var r = ctx.nodes[ctx.edges[q].value].first;
                while r >= 0 { if ctx.nodes[ctx.edges[r].value].symbol == vt { covered = true; } r = ctx.edges[r].next; }
                q = ctx.edges[q].next;
            }
            if !covered { error_at(ctx, x.token, str("match does not cover variant ", ctx.tokens[ctx.nodes[st.decl].token].text, ".", ctx.tokens[ctx.nodes[ctx.types[vt].decl].token].text)); }
            v = ctx.edges[v].next;
        }
    }
    var result = Value {};
    var previous = -1;
    e = x.first;
    while e >= 0 {
        let arm = ctx.edges[e].value;
        let inner = scope_new(ctx, scope, ctx.checking_function);
        let binder = ctx.nodes[arm].b;
        if binder >= 0 {
            let vt = ctx.nodes[first_child(ctx, arm)].symbol;
            let variant = ctx.tokens[ctx.nodes[first_child(ctx, arm)].token].text;
            if !has_payload(ctx, vt) { error_at(ctx, ctx.nodes[binder].token, str("variant ", variant, " has no payload to bind")); }
            let by_reference = ctx.nodes[arm].flags & 1 != 0;
            if by_reference && st.flags & 1 == 0 { error_at(ctx, ctx.nodes[binder].token, str("cannot bind the payload of fixed-mode ", ctx.tokens[ctx.nodes[st.decl].token].text, " by reference (§3.5); bind by value: ", variant, " ", ctx.tokens[ctx.nodes[binder].token].text)); }
            if !by_reference && ctx.types[vt].size_class != 0 { error_at(ctx, ctx.nodes[binder].token, "not implemented yet: a by-value binder of a variable-size payload"); }
            // A payload copy that cannot be written, as a by-value for binding;
            // in variable mode &b refers into the payload where it lies.
            let b = register_symbol(ctx, ctx.nodes[binder].token, -1, 2, arm, inner, if by_reference { 0 } else { 32 });
            ctx.symbols[b].ty = if by_reference { reference_type(ctx, vt, s.readonly) } else { vt };
            ctx.symbols[b].state = 2; ctx.symbols[b].root = s.root; ctx.symbols[b].held = s.held;
            ctx.symbols[b].readonly = by_reference && s.readonly;
            ctx.nodes[binder].symbol = b;
        }
        let body = ctx.nodes[arm].c;
        let a = check_expression(ctx, body, inner, expected);
        check_branch_value(ctx, n, a, body, inner, "match arm", expected);
        if previous < 0 { result = a; result.place = -1; result.known = false; }
        else { result = join_branch(ctx, result, a, previous, body, x.token); }
        previous = body;
        e = ctx.edges[e].next;
    }
    return result;
}

// User format overloads (§3.7): fn format(out: u8[>..]&, v: T), T by value or
// by reference, renders every T wherever one occurs in a rendered argument.
// The choice is made once per type, for everything reachable from what is
// rendered; a type an overload renders is not walked further.
recursive fn prepare_rendering(ctx: Compiler&, ty: i64, token: i64) {
    if ctx.types[ty].formatter != -2 { return; }
    ctx.types[ty].formatter = -1;
    let spec = find_formatter(ctx, ty, token);
    if spec >= 0 { ctx.types[ty].formatter = spec; ctx.formatters++; return; }
    let t = ctx.types[ty];
    var e = t.first;
    if t.kind == T_STRUCT { while e >= 0 { prepare_rendering(ctx, ctx.fielddefs[ctx.edges[e].value].ty, token); e = ctx.edges[e].next; } }
    if t.kind == T_ENUM { while e >= 0 { prepare_rendering(ctx, ctx.edges[e].value, token); e = ctx.edges[e].next; } }
    if t.kind == T_ARRAY || t.kind == T_SLICE || t.kind == T_REFERENCE { prepare_rendering(ctx, t.element, token); }
}
// A call format(out, v) for a builder and a T that both lie in storage.
fn format_call(ctx: Compiler&, ty: i64, token: i64) -> i64 {
    let call = node(ctx, N_CALL, token); ctx.nodes[call].a = node(ctx, N_NAME, token); ctx.nodes[call].flags = 512;
    for arg_ty in [array_type(ctx, integer_type(ctx, 1, true), 3, -1), ty] {
        let holder = ctx.symbols.len;
        ctx.symbols.push(Symbol { token: token, ns: -1, kind: 4, decl: call, scope: 0, ty: arg_ty, state: 2 });
        index_symbol(ctx, holder);
        let arg = node(ctx, N_NAME, token);
        annotate(ctx, arg, Value { ty: arg_ty, root: holder, place: holder });
        child(ctx, call, arg);
    }
    return call;
}
// A generic overload on a bare type variable, or an array or slice of one,
// is an ordinary overload and does not render.
fn bare_type_variable(ctx: Compiler&, decl: i64, pattern: i64) -> bool {
    if pattern < 0 { return true; }
    var p = pattern;
    if ctx.nodes[p].tag == N_TYPE_ARRAY || ctx.nodes[p].tag == N_TYPE_SLICE || ctx.nodes[p].tag == N_TYPE_REF { p = ctx.nodes[p].a; }
    if ctx.nodes[p].tag != N_TYPE || ctx.nodes[p].first >= 0 { return false; }
    var g = ctx.nodes[decl].first;
    while g >= 0 { if same_name(ctx, ctx.nodes[ctx.edges[g].value].token, ctx.nodes[p].token) { return true; } g = ctx.edges[g].next; }
    return false;
}
fn second_parameter(ctx: Compiler&, decl: i64) -> i64 { ctx.edges[ctx.edges[ctx.nodes[ctx.nodes[decl].a].first].next].value }
recursive fn find_formatter(ctx: Compiler&, ty: i64, token: i64) -> i64 {
    var best = -1; var best_tier = 3; var call = -1;
    let limit = ctx.symbols.len;
    for i in limit {
        let s = ctx.symbols[i];
        if s.kind != 3 || s.scope != 0 || ctx.tokens[s.token].text != "format" { continue; }
        let d = s.decl;
        if child_count(ctx, ctx.nodes[d].a) != 2 || ctx.nodes[d].flags & 2 != 0 { continue; }
        var concrete = i; var tier = 0;
        if ctx.nodes[d].first >= 0 || ctx.nodes[second_parameter(ctx, d)].a < 0 {
            if bare_type_variable(ctx, d, ctx.nodes[second_parameter(ctx, d)].a) { continue; }
            if call < 0 { call = format_call(ctx, ty, token); }
            tier = 1; concrete = specialize_signature(ctx, i, call, 0, true);
            if concrete < 0 { continue; }
        }
        let cd = ctx.symbols[concrete].decl;
        let given = resolve_type(ctx, ctx.nodes[second_parameter(ctx, cd)].a, ctx.symbols[concrete].scope);
        if given != ty && !(ctx.types[given].kind == T_REFERENCE && ctx.types[given].element == ty) { continue; }
        // The type's own namespace is searched before the global one.
        if s.ns >= 0 {
            if ctx.types[ty].decl < 0 || !same_name(ctx, s.ns, ctx.nodes[ctx.types[ty].decl].ns) { continue; }
            tier -= 1;
        }
        if tier < best_tier { best = concrete; best_tier = tier; }
    }
    if best < 0 { return -1; }
    if call < 0 { call = format_call(ctx, ty, token); }
    return check_function(ctx, best, call, 0);
}

recursive fn check_array(ctx: Compiler&, n: i64, scope: i64, expected: i64) -> Value {
    let x = ctx.nodes[n];
    var element = -1;
    if expected >= 0 { element = element_type(ctx, expected); }
    var count = 0;
    var root = -1;
    if x.tag == N_LIMITED {
        if element < 0 { error_at(ctx, x.token, "limited literal needs an element type"); }
        require_fit(ctx, x.a, decay(ctx, check_expression(ctx, x.a, scope, -1)), default_integer(ctx));
        return Value { ty: array_type(ctx, element, 2, -1) };
    }
    if x.tag == N_FILL {
        let a = decay(ctx, check_expression(ctx, x.a, scope, element));
        if element < 0 { element = a.ty; } else { require_fit(ctx, x.a, a, element); }
        count = constant_integer(ctx, x.b) as i64; root = a.root;
    } else {
        var e = x.first;
        while e >= 0 {
            let item = ctx.edges[e].value; let a = decay(ctx, check_expression(ctx, item, scope, element));
            if element < 0 { element = a.ty; } else { require_fit(ctx, item, a, element); }
            check_stored_view(ctx, received(ctx, a, element), ctx.nodes[item].token);
            if root_depth(ctx, content_root(ctx, received(ctx, a, element))) >= root_depth(ctx, root) { root = content_root(ctx, received(ctx, a, element)); }
            count++; e = ctx.edges[e].next;
        }
    }
    if element < 0 { error_at(ctx, x.token, "empty array needs an element type"); }
    no_fieldless_element(ctx, element, x.token);
    var ty = array_type(ctx, element, 0, count);
    if ctx.types[element].size_class > 0 { ty = array_type(ctx, element, 1, 4); }
    if ty < 0 { error_at(ctx, x.token, "invalid array element type"); }
    return Value { ty: ty, held: root };
}
// The type a name expression spells, with its written type arguments.
fn type_syntax(ctx: Compiler&, name: i64) -> i64 {
    let t = node(ctx, N_TYPE, ctx.nodes[name].token);
    ctx.nodes[t].ns = ctx.nodes[name].ns; ctx.nodes[t].flags = ctx.nodes[name].flags;
    ctx.nodes[t].first = ctx.nodes[name].first; ctx.nodes[t].last = ctx.nodes[name].last;
    return t;
}
// The enum a name denotes where it is not a variable: Shape in Shape.Dot.
fn variant_owner(ctx: Compiler&, n: i64, scope: i64) -> i64 {
    if ctx.nodes[n].tag != N_NAME || lookup(ctx, n, scope, 2) >= 0 || lookup(ctx, n, scope, 1) < 0 { return -1; }
    let ty = resolve_type(ctx, type_syntax(ctx, n), scope);
    if ctx.types[ty].kind == T_ENUM { return ty; }
    return -1;
}
recursive fn check_construct(ctx: Compiler&, n: i64, scope: i64) -> Value {
    let name = ctx.nodes[n].a;
    var ty = -1;
    if ctx.nodes[name].tag == N_MEMBER {
        let owner = variant_owner(ctx, ctx.nodes[name].a, scope);
        if owner < 0 { error_at(ctx, ctx.nodes[name].token, "variant literal of non-ADT type"); }
        let variant = node(ctx, N_TYPE_MEMBER, ctx.nodes[name].token); ctx.nodes[variant].a = type_syntax(ctx, ctx.nodes[name].a);
        ty = resolve_type(ctx, variant, scope);
    } else {
        if ctx.nodes[name].tag != N_NAME || lookup(ctx, name, scope, 1) < 0 { error_at(ctx, ctx.nodes[name].token, "unknown constructor"); }
        ty = resolve_type(ctx, type_syntax(ctx, name), scope);
    }
    if ctx.types[ty].kind != T_STRUCT { error_at(ctx, ctx.nodes[n].token, "constructor needs a struct type"); }
    var f = ctx.types[ty].first; var e = ctx.nodes[n].first;
    ctx.nodes[n].first = -1; ctx.nodes[n].last = -1;
    var root = -1;
    while f >= 0 {
        let field = ctx.edges[f].value;
        var init = -1;
        if e >= 0 {
            let written = ctx.edges[e].value;
            if ctx.nodes[written].flags == 0 || same_name(ctx, ctx.nodes[written].token, ctx.fielddefs[field].token) { init = ctx.nodes[written].a; ctx.nodes[written].symbol = field; e = ctx.edges[e].next; }
        }
        var init_scope = scope;
        var type_default = false;
        var field_default = false;
        if init < 0 {
            if ctx.fielddefs[field].initializer >= 0 {
                init = clone_tree(ctx, ctx.fielddefs[field].initializer);
                init_scope = ctx.types[ty].scope;
                field_default = true;
            } else if ctx.nodes[n].flags & 1 != 0 {
                if ctx.types[ctx.fielddefs[field].ty].size_class != 0 && !(ctx.types[ctx.fielddefs[field].ty].kind == T_ARRAY) { error_at(ctx, ctx.nodes[n].token, str("field '", ctx.tokens[ctx.fielddefs[field].token].text, "' has no default value")); }
                if ctx.types[ctx.fielddefs[field].ty].kind == T_REFERENCE { error_at(ctx, ctx.nodes[n].token, str("field '", ctx.tokens[ctx.fielddefs[field].token].text, "' is a reference, which has no default value")); }
                init = type_default_value(ctx, ctx.fielddefs[field].ty, ctx.nodes[n].token);
                type_default = true;
            } else if is_optional(ctx, ctx.fielddefs[field].ty) { init = node(ctx, N_NULL, ctx.nodes[n].token); }
            else { error_at(ctx, ctx.nodes[n].token, str("missing field '", ctx.tokens[ctx.fielddefs[field].token].text, "'")); }
        }
        let added = node(ctx, N_INIT, ctx.fielddefs[field].token); ctx.nodes[added].a = init; ctx.nodes[added].symbol = field; child(ctx, n, added);
        // A default may not lead to a construction that takes it again (3.2).
        let defaults = ctx.default_stack; let mark = defaults.len;
        if field_default {
            var i = defaults.len;
            while i > 0 && defaults[i - 1] != -1 {
                i--;
                if defaults[i] == -2 - field {
                    var text: u8[>..] = [];
                    format(text, "the default of field ", ctx.tokens[ctx.fielddefs[field].token].text, " of "); type_text(ctx, field_owner(ctx, field), text);
                    text.append(" leads to this construction of "); type_text(ctx, ty, text); text.append(", which takes it again");
                    error_at(ctx, ctx.nodes[n].token, text);
                }
            }
            defaults.push(-2 - field);
        }
        let v = if type_default { value_of(ctx, init) } else { check_expression(ctx, init, init_scope, ctx.fielddefs[field].ty) };
        defaults.resize(mark);
        require_fit(ctx, init, v, ctx.fielddefs[field].ty);
        let stored = received(ctx, v, ctx.fielddefs[field].ty);
        check_stored_view(ctx, stored, ctx.nodes[init].token);
        if contains_view(ctx, stored.ty) && root_depth(ctx, content_root(ctx, stored)) >= root_depth(ctx, root) { root = content_root(ctx, stored); }
        f = ctx.edges[f].next;
    }
    if e >= 0 { error_at(ctx, ctx.nodes[ctx.edges[e].value].token, "unknown or out-of-order field initializer"); }
    return Value { ty: ty, held: root, fields: ctx.nodes[n].first };
}
fn field_owner(ctx: Compiler&, field: i64) -> i64 {
    for t, i in ctx.types {
        if t.kind != T_STRUCT { continue; }
        var e = t.first;
        while e >= 0 { if ctx.edges[e].value == field { return i; } e = ctx.edges[e].next; }
    }
    return -1;
}
// The value a type has before anything is written to it, as default<T>()
// gives it: a checked call of that builtin, for a construction to emit.
fn type_default_value(ctx: Compiler&, ty: i64, token: i64) -> i64 {
    let n = node(ctx, N_CALL, token);
    ctx.nodes[n].symbol = -27; ctx.nodes[n].a = node(ctx, N_NAME, token);
    annotate(ctx, n, Value { ty: ty });
    return n;
}
recursive fn check_block(ctx: Compiler&, n: i64, parent: i64, expected: i64) -> Value {
    let scope = scope_new(ctx, parent, ctx.checking_function);
    ctx.nodes[n].symbol = scope;
    var declaration = ctx.nodes[n].first;
    while declaration >= 0 {
        let d = ctx.edges[declaration].value;
        if ctx.nodes[d].tag == N_FUNCTION { ctx.nodes[d].symbol = register_symbol(ctx, ctx.nodes[d].token, ctx.nodes[d].ns, 3, d, scope, 0); }
        declaration = ctx.edges[declaration].next;
    }
    var e = ctx.nodes[n].first;
    var terminated = false;
    while e >= 0 { let statement = check_expression(ctx, ctx.edges[e].value, scope, -1); if ctx.types[statement.ty].kind == T_BOTTOM { terminated = true; } e = ctx.edges[e].next; }
    var result = Value {};
    if ctx.nodes[n].a >= 0 { result = check_expression(ctx, ctx.nodes[n].a, scope, expected); }
    else if terminated { result.ty = intern_type(ctx, Type { kind: T_BOTTOM }); }
    if contains_view(ctx, result.ty) && content_root(ctx, result) >= 0 && scope_contains(ctx, scope, ctx.symbols[content_root(ctx, result)].scope) { error_at(ctx, ctx.nodes[n].token, "block result refers to a local or temporary that has ended"); }
    return result;
}
// Each result keeps its own lifetime bound. Several results are a calling
// convention, so only projections of a call can supply a multi-name receiver.
fn result_value(ctx: Compiler&, result: i64) -> Value {
    var v = value_of(ctx, result); v.place = -1; v.held = v.root; v.known = false;
    return v;
}
recursive fn resolve_result_type(ctx: Compiler&, n: i64, scope: i64, multiple: bool) -> i64 {
    let syntax = ctx.nodes[n];
    if multiple && syntax.tag == N_TYPE_ARRAY {
        let mode = syntax.flags & 15;
        // Recognize unsupported non-fixed headers before general storage
        // resolution rejects them, including through a type alias.
        if mode == 1 || mode >= 3 || (mode == 2 && (syntax.b < 0 || ctx.nodes[syntax.b].tag == N_TYPE)) { error_at(ctx, syntax.token, "not implemented yet: non-fixed multiple results"); }
    }
    if multiple && syntax.tag == N_TYPE {
        let s = lookup(ctx, n, scope, 1);
        if s >= 0 && ctx.symbols[s].decl >= 0 && ctx.nodes[ctx.symbols[s].decl].tag == N_ALIAS {
            if ctx.symbols[s].state == 1 { error_at(ctx, syntax.token, "cyclic type alias"); }
            if syntax.first >= 0 { error_at(ctx, syntax.token, "a type alias takes no type arguments"); }
            ctx.symbols[s].state = 1;
            let ty = resolve_result_type(ctx, ctx.nodes[ctx.symbols[s].decl].a, ctx.symbols[s].scope, true);
            ctx.symbols[s].state = 2; return ty;
        }
    }
    return resolve_type(ctx, n, scope);
}
fn reject_nonfixed_results(ctx: Compiler&, results: i64) {
    if child_count(ctx, results) < 2 { return; }
    var e = ctx.nodes[results].first;
    while e >= 0 {
        let r = ctx.edges[e].value;
        if ctx.nodes[r].ty >= 0 && ctx.types[ctx.nodes[r].ty].size_class > 0 { error_at(ctx, ctx.nodes[r].token, "not implemented yet: non-fixed multiple results"); }
        e = ctx.edges[e].next;
    }
}
fn result_call(ctx: Compiler&, n: i64) -> i64 {
    var call = n;
    while call >= 0 && ctx.nodes[call].tag == N_UNARY && ctx.tokens[ctx.nodes[call].token].text == "(" { call = ctx.nodes[call].a; }
    if call >= 0 && ctx.nodes[call].tag == N_CALL && ctx.nodes[call].symbol >= 0 { return call; }
    return -1;
}
fn call_result_count(ctx: Compiler&, call: i64) -> i64 {
    if call < 0 { return 1; }
    return child_count(ctx, ctx.specializations[ctx.nodes[call].symbol].results);
}
fn project_result(ctx: Compiler&, call: i64, index: i64, scope: i64) -> i64 {
    var e = ctx.nodes[ctx.specializations[ctx.nodes[call].symbol].results].first;
    for i in index { e = ctx.edges[e].next; }
    let n = node(ctx, N_RESULT, ctx.nodes[call].token);
    ctx.nodes[n].a = call; ctx.nodes[n].flags = index;
    var v = result_value(ctx, ctx.edges[e].value);
    if ctx.types[v.ty].kind == T_ARRAY || ctx.types[v.ty].kind == T_STRUCT {
        let temporary_scope = scope_new(ctx, scope, ctx.checking_function);
        v.root = ctx.symbols.len;
        ctx.symbols.push(Symbol { token: ctx.nodes[n].token, ns: -1, kind: 4, decl: n, scope: temporary_scope, ty: v.ty, state: 2 });
        index_symbol(ctx, v.root);
    }
    annotate(ctx, n, v);
    return n;
}
recursive fn check_returns(ctx: Compiler&, n: i64, scope: i64) {
    let spec = ctx.checking_function;
    let results = ctx.specializations[spec].results;
    var count = child_count(ctx, n);
    var call = -1;
    if count == 1 {
        let value = first_child(ctx, n);
        check_expression(ctx, value, scope, ctx.specializations[spec].result);
        call = result_call(ctx, value);
        count = call_result_count(ctx, call);
    }
    let first = first_child(ctx, results);
    if ctx.nodes[first].ty < 0 && count > 1 {
        for i in 1..count { child(ctx, results, node(ctx, N_PAD, ctx.nodes[n].token)); }
    }
    if count != child_count(ctx, results) && !(count == 0 && child_count(ctx, results) == 1) { error_at(ctx, ctx.nodes[n].token, "return result count mismatch"); }
    if call >= 0 && count > 1 {
        ctx.nodes[n].b = call; ctx.nodes[n].first = -1; ctx.nodes[n].last = -1;
        for i in count { child(ctx, n, project_result(ctx, call, i, scope)); }
    }
    var e = ctx.nodes[n].first; var re = ctx.nodes[results].first;
    while re >= 0 {
        let r = ctx.edges[re].value;
        var value = -1; var raw = Value {};
        if e >= 0 {
            value = ctx.edges[e].value;
            // A single written expression was already checked above. A
            // forwarded call is represented by its checked projections.
            raw = if child_count(ctx, n) == 1 || ctx.nodes[n].b >= 0 { value_of(ctx, value) } else { check_expression(ctx, value, scope, ctx.nodes[r].ty) };
            e = ctx.edges[e].next;
        }
        check_result(ctx, value, raw, spec, r, ctx.nodes[n].token);
        re = ctx.edges[re].next;
    }
    reject_nonfixed_results(ctx, results);
}
recursive fn check_receiving(ctx: Compiler&, n: i64, scope: i64, binding: bool) {
    let x = ctx.nodes[n];
    if binding && child_count(ctx, x.b) != 1 { error_at(ctx, x.token, "a binding needs one initializer"); }
    let init = if binding { first_child(ctx, x.b) } else { x.b };
    check_expression(ctx, init, scope, -1);
    let call = result_call(ctx, init);
    let count = child_count(ctx, n);
    if call < 0 || call_result_count(ctx, call) != count { error_at(ctx, x.token, "binding or assignment result count mismatch"); }
    ctx.nodes[n].tag = N_RECEIVE; ctx.nodes[n].a = call; ctx.nodes[n].b = -1;
    ctx.nodes[n].first = -1; ctx.nodes[n].last = -1;
    var e = x.first; var index = 0;
    while e >= 0 {
        let dest = ctx.edges[e].value;
        let value = project_result(ctx, call, index, scope);
        let receiver = node(ctx, if binding { N_BIND } else { N_ASSIGN }, x.token);
        if binding {
            ctx.nodes[receiver].flags = x.flags; ctx.nodes[receiver].a = x.a;
            child(ctx, receiver, dest);
            let values = node(ctx, N_BLOCK, x.token); child(ctx, values, value); ctx.nodes[receiver].b = values;
            check_binding(ctx, receiver, scope);
        } else {
            ctx.nodes[receiver].a = dest; ctx.nodes[receiver].b = value;
            check_assignment(ctx, receiver, scope);
        }
        child(ctx, n, receiver); e = ctx.edges[e].next; index++;
    }
}

recursive fn check_binding(ctx: Compiler&, n: i64, scope: i64) {
    if child_count(ctx, n) > 1 { check_receiving(ctx, n, scope, true); return; }
    if child_count(ctx, ctx.nodes[n].b) > 1 { error_at(ctx, ctx.nodes[n].token, "a binding needs one initializer"); }
    let name = first_child(ctx, n);
    var s = ctx.nodes[name].symbol;
    if scope != 0 { s = register_symbol(ctx, ctx.nodes[name].token, ctx.nodes[name].ns, 2, n, scope, ctx.nodes[n].flags); ctx.nodes[name].symbol = s; }
    var declared = -1;
    if ctx.nodes[n].a >= 0 { declared = resolve_type(ctx, ctx.nodes[n].a, scope); }
    var init = first_child(ctx, ctx.nodes[n].b);
    var synthesized = false;
    if init < 0 && scope == 0 && declared >= 0 {
        // A global given only a type starts as its type's default value.
        let syntax = ctx.nodes[ctx.nodes[n].a];
        if ctx.types[declared].kind == T_STRUCT && !is_variant(ctx, declared) && syntax.tag == N_TYPE {
            init = node(ctx, N_CONSTRUCT, ctx.nodes[n].token); ctx.nodes[init].flags = 1;
            let name = node(ctx, N_NAME, syntax.token); ctx.nodes[name].ns = syntax.ns; ctx.nodes[name].flags = syntax.flags & 1; ctx.nodes[name].first = syntax.first; ctx.nodes[name].last = syntax.last;
            ctx.nodes[init].a = name;
        } else { init = type_default_value(ctx, declared, ctx.nodes[n].token); synthesized = true; }
        let values = node(ctx, N_BLOCK, ctx.nodes[n].token); child(ctx, values, init); ctx.nodes[n].b = values;
    }
    if init < 0 {
        if declared < 0 { error_at(ctx, ctx.nodes[n].token, "uninitialized variable needs a type"); }
        ctx.symbols[s].ty = declared; return;
    }
    let raw = if synthesized { value_of(ctx, init) } else { check_expression(ctx, init, scope, declared) };
    if ctx.types[raw.ty].kind == T_BOTTOM || raw.ty == 0 { error_at(ctx, ctx.nodes[init].token, "initializer has no value"); }
    var v = decay(ctx, raw);
    if declared < 0 {
        declared = v.ty;
        // A narrowed read of an optional slot still binds an optional.
        let slot = plain_reference(ctx, slot_type(ctx, init));
        if ctx.nodes[n].flags & 16 == 0 && is_optional(ctx, slot) && ctx.types[raw.ty].kind == T_REFERENCE && ctx.types[raw.ty].element == ctx.types[slot].element { declared = slot; v = raw; }
        else if ctx.nodes[n].flags & 16 != 0 || ((v.place >= 0 || ctx.types[raw.ty].kind == T_REFERENCE) && ctx.types[v.ty].size_class > 0) || (ctx.nodes[init].tag == N_UNARY && ctx.tokens[ctx.nodes[init].token].text == "&") { declared = reference_type(ctx, v.ty, v.readonly); }
    }
    if ctx.types[declared].kind == T_REFERENCE { v = raw; }
    if ctx.types[declared].size_class > 0 && !adapts_enum(ctx, decay(ctx, raw).ty, declared) && (raw.place >= 0 || ctx.types[raw.ty].kind == T_REFERENCE) { error_at(ctx, ctx.nodes[init].token, "nonfixed storage is not copied implicitly; use copy or bind by reference"); }
    require_fit(ctx, init, v, declared);
    if ctx.nodes[n].flags & 4 != 0 && (ctx.types[declared].kind != T_ARRAY || ctx.types[declared].flags != 3 || ctx.types[ctx.types[declared].element].size_class != 0) { error_at(ctx, ctx.nodes[n].token, "reusable needs a grow-only array of fixed-size elements"); }
    ctx.symbols[s].ty = declared; ctx.symbols[s].state = 2; ctx.symbols[s].root = v.root;
    if ctx.types[declared].kind == T_REFERENCE && !is_optional(ctx, declared) { ctx.symbols[s].pool_kind = builtin_pool_kind(ctx, raw); }
    ctx.symbols[s].held = v.held;
    ctx.symbols[s].fields = raw.fields;
    ctx.symbols[s].growshrink = raw.growshrink;
    ctx.symbols[s].inexact = raw.inexact;
    ctx.symbols[s].readonly = syntax_readonly(ctx, ctx.nodes[n].a, scope) || ((ctx.types[declared].kind == T_REFERENCE || ctx.types[declared].kind == T_SLICE) && raw.readonly);
    if ctx.nodes[n].flags & 1 == 0 && ctx.nodes[init].tag == N_MEMBER && ctx.tokens[ctx.nodes[init].token].text == "len" {
        let receiver = ctx.nodes[init].a;
        let owner = decay(ctx, value_of(ctx, receiver));
        if owner.root >= 0 && ctx.types[owner.ty].kind == T_ARRAY && ctx.types[owner.ty].flags == 4 && stable_array_path(ctx, receiver) { ctx.symbols[s].length_root = owner.root; }
    }
    if ctx.nodes[n].flags & 1 == 0 && v.known { ctx.symbols[s].known = true; ctx.symbols[s].bits = v.bits; }
    store_lifetime(ctx, Value { ty: declared, root: v.root, held: v.held }, s, ctx.nodes[n].token);
    if is_optional(ctx, declared) && non_null(ctx, raw) { ctx.flow = fact_add(ctx, ctx.flow, name); }
}

// Optional narrowing. A flow state is a persistent list in ctx.edges of the
// checked path nodes (a name, a field or a constant index of one) known not
// to be null; branches save and join states as plain list heads.
recursive fn same_path(ctx: Compiler&, a: i64, b: i64) -> bool {
    let x = ctx.nodes[a]; let y = ctx.nodes[b];
    if x.tag == N_UNARY && ctx.tokens[x.token].text == "(" { return same_path(ctx, x.a, b); }
    if y.tag == N_UNARY && ctx.tokens[y.token].text == "(" { return same_path(ctx, a, y.a); }
    if x.tag != y.tag { return false; }
    if x.tag == N_NAME { return x.symbol >= 0 && x.symbol == y.symbol; }
    if x.tag == N_MEMBER { return same_name(ctx, x.token, y.token) && same_path(ctx, x.a, y.a); }
    if x.tag == N_INDEX {
        if x.b < 0 || y.b < 0 || ctx.nodes[x.b].tag != N_INT || ctx.nodes[y.b].tag != N_INT || x.flags != y.flags { return false; }
        return ctx.tokens[ctx.nodes[x.b].token].integer == ctx.tokens[ctx.nodes[y.b].token].integer && same_path(ctx, x.a, y.a);
    }
    return false;
}
// The same path written in unchecked syntax: compared by spelling.
recursive fn same_path_text(ctx: Compiler&, a: i64, b: i64) -> bool {
    let x = ctx.nodes[a]; let y = ctx.nodes[b];
    if x.tag == N_UNARY && ctx.tokens[x.token].text == "(" { return same_path_text(ctx, x.a, b); }
    if y.tag == N_UNARY && ctx.tokens[y.token].text == "(" { return same_path_text(ctx, a, y.a); }
    if x.tag != y.tag { return false; }
    if x.tag == N_NAME { return same_name(ctx, x.token, y.token); }
    if x.tag == N_MEMBER { return same_name(ctx, x.token, y.token) && same_path_text(ctx, x.a, y.a); }
    if x.tag == N_INDEX { return x.b >= 0 && y.b >= 0 && ctx.nodes[x.b].tag == N_INT && ctx.nodes[y.b].tag == N_INT && ctx.tokens[ctx.nodes[x.b].token].integer == ctx.tokens[ctx.nodes[y.b].token].integer && same_path_text(ctx, x.a, y.a); }
    return false;
}
// Whether prefix names path or a part of the storage path reaches through.
fn path_has_prefix(ctx: Compiler&, path: i64, prefix: i64, strict: bool, text: bool) -> bool {
    var p = path; var first = true;
    while p >= 0 {
        let x = ctx.nodes[p];
        if !(first && strict) {
            if text && same_path_text(ctx, p, prefix) { return true; }
            if !text && same_path(ctx, p, prefix) { return true; }
        }
        first = false;
        if x.tag == N_MEMBER || x.tag == N_INDEX || (x.tag == N_UNARY && ctx.tokens[x.token].text == "(") { p = x.a; } else { p = -1; }
    }
    return false;
}
fn path_root(ctx: Compiler&, path: i64) -> i64 {
    var p = path;
    while p >= 0 {
        let x = ctx.nodes[p];
        if x.tag == N_NAME { return x.symbol; }
        if x.tag == N_MEMBER || x.tag == N_INDEX || x.tag == N_UNARY { p = x.a; } else { return -1; }
    }
    return -1;
}
fn fact_known(ctx: Compiler&, state: i64, n: i64) -> bool {
    var e = state;
    while e >= 0 { if same_path(ctx, ctx.edges[e].value, n) { return true; } e = ctx.edges[e].next; }
    return false;
}
fn fact_add(ctx: Compiler&, state: i64, n: i64) -> i64 {
    if fact_known(ctx, state, n) { return state; }
    let id = ctx.edges.len; ctx.edges.push(Edge { value: n, next: state }); return id;
}
// Drops the facts about storage reached through path (kind 0: path or any
// part of it, 1: strictly inside it, 2: spelled like it, 3: rooted at symbol).
fn fact_kill(ctx: Compiler&, state: i64, path: i64, kind: i64) -> i64 {
    var kept = -1; var e = state; var changed = false;
    while e >= 0 {
        let fact = ctx.edges[e].value;
        var dead = false;
        if kind == 0 || kind == 1 { dead = path_has_prefix(ctx, fact, path, kind == 1, false); }
        else if kind == 2 { dead = path_has_prefix(ctx, fact, path, false, true); }
        else { dead = path_root(ctx, fact) == path; }
        if dead { changed = true; } else { let id = ctx.edges.len; ctx.edges.push(Edge { value: fact, next: kept }); kept = id; }
        e = ctx.edges[e].next;
    }
    if !changed { return state; }
    return kept;
}
fn fact_meet(ctx: Compiler&, a: i64, b: i64) -> i64 {
    if a == b { return a; }
    var kept = -1; var e = a;
    while e >= 0 {
        let fact = ctx.edges[e].value;
        if fact_known(ctx, b, fact) { let id = ctx.edges.len; ctx.edges.push(Edge { value: fact, next: kept }); kept = id; }
        e = ctx.edges[e].next;
    }
    return kept;
}
// Kills the facts a loop body may invalidate by a rebinding, before it runs.
recursive fn fact_kill_rebinds(ctx: Compiler&, state: i64, n: i64) -> i64 {
    if n < 0 || state < 0 { return state; }
    let x = ctx.nodes[n];
    if x.tag == N_FUNCTION { return state; }
    var result = state;
    if x.tag == N_ASSIGN && x.a >= 0 && ctx.tokens[x.token].text == ".=" { result = fact_kill(ctx, result, x.a, 2); }
    result = fact_kill_rebinds(ctx, result, x.a);
    result = fact_kill_rebinds(ctx, result, x.b);
    result = fact_kill_rebinds(ctx, result, x.c);
    var e = x.first;
    while e >= 0 { result = fact_kill_rebinds(ctx, result, ctx.edges[e].value); e = ctx.edges[e].next; }
    return result;
}
// The facts that hold when condition n evaluates to truth.
recursive fn condition_facts(ctx: Compiler&, n: i64, truth: bool, state: i64) -> i64 {
    let x = ctx.nodes[n];
    if x.tag == N_UNARY {
        let op = ctx.tokens[x.token].text;
        if op == "(" { return condition_facts(ctx, x.a, truth, state); }
        if op == "!" { return condition_facts(ctx, x.a, !truth, state); }
    }
    if x.tag == N_BINARY {
        let op = ctx.tokens[x.token].text;
        if op == "&&" { if truth { return condition_facts(ctx, x.b, true, condition_facts(ctx, x.a, true, state)); } return state; }
        if op == "||" { if !truth { return condition_facts(ctx, x.b, false, condition_facts(ctx, x.a, false, state)); } return state; }
        if op == "==" || op == "!=" {
            var other = -1;
            if ctx.nodes[x.b].tag == N_NULL { other = x.a; } else if ctx.nodes[x.a].tag == N_NULL { other = x.b; }
            if other >= 0 && truth == (op == "!=") { return fact_add(ctx, state, other); }
        }
        return state;
    }
    if x.truth && truth { return fact_add(ctx, state, n); }
    return state;
}
// The declared type of the slot a path names, before any narrowing.
recursive fn slot_type(ctx: Compiler&, n: i64) -> i64 {
    let x = ctx.nodes[n];
    if x.tag == N_UNARY && ctx.tokens[x.token].text == "(" { return slot_type(ctx, x.a); }
    if x.tag == N_NAME && x.symbol >= 0 { return ctx.symbols[x.symbol].ty; }
    if x.tag == N_MEMBER && x.symbol >= 0 { let base = decay(ctx, value_of(ctx, x.a)).ty; if base >= 0 && ctx.types[base].kind == T_STRUCT { return ctx.fielddefs[x.symbol].ty; } }
    if x.tag == N_INDEX && ctx.nodes[x.a].ty >= 0 { return element_type(ctx, ctx.nodes[x.a].ty); }
    return -1;
}
// A condition is a bool, or an optional tested for null.
fn require_condition(ctx: Compiler&, n: i64, v: Value) {
    if is_optional(ctx, v.ty) || is_optional(ctx, slot_type(ctx, n)) { ctx.nodes[n].truth = true; return; }
    require_fit(ctx, n, decay(ctx, v), boolean_type(ctx));
}
fn narrowed(ctx: Compiler&, n: i64, v: Value) -> Value {
    var r = v;
    if is_optional(ctx, v.ty) && fact_known(ctx, ctx.flow, n) { r.ty = reference_type(ctx, ctx.types[v.ty].element, ctx.types[v.ty].flags & 1 != 0); }
    return r;
}
// Whether a value bound into an optional slot is certainly not null.
fn non_null(ctx: Compiler&, v: Value) -> bool {
    let t = ctx.types[v.ty];
    if t.kind == T_NULL { return false; }
    if t.kind == T_REFERENCE { return t.flags & 4 == 0; }
    return true;
}
fn record_rebind(ctx: Compiler&, symbol: i64) {
    if symbol < 0 || ctx.symbols[symbol].scope != 0 || ctx.checking_function < 0 { return; }
    var e = ctx.specializations[ctx.checking_function].rebinds;
    while e >= 0 { if ctx.edges[e].value == symbol { return; } e = ctx.edges[e].next; }
    let id = ctx.edges.len; ctx.edges.push(Edge { value: symbol, next: ctx.specializations[ctx.checking_function].rebinds });
    ctx.specializations[ctx.checking_function].rebinds = id;
}
fn generic_code(ctx: Compiler&, spec: i64) -> bool {
    var f = spec;
    while f >= 0 {
        let symbol = ctx.symbols[ctx.specializations[f].symbol];
        if symbol.kind == 5 { return true; }
        f = ctx.scopes[symbol.scope].function;
    }
    return false;
}
// `p .= e` rebinds the reference or optional slot p.
recursive fn check_rebind(ctx: Compiler&, n: i64, scope: i64) {
    let x = ctx.nodes[n];
    let raw = check_expression(ctx, x.a, scope, -1);
    let slot = slot_type(ctx, x.a);
    if slot < 0 || ctx.types[slot].kind != T_REFERENCE { error_at(ctx, x.token, ".= rebinds references only"); }
    let target = ctx.nodes[x.a];
    if target.tag == N_NAME && ctx.symbols[target.symbol].flags & 1 == 0 { error_at(ctx, x.token, "cannot rebind a let reference"); }
    if target.tag != N_NAME && raw.readonly { error_at(ctx, x.token, "cannot write through read-only storage"); }
    let rhs = check_expression(ctx, x.b, scope, slot);
    require_fit(ctx, x.b, rhs, slot);
    let stored = Value { ty: slot, root: rhs.root, growshrink: rhs.growshrink, held: rhs.held };
    if target.tag == N_NAME {
        let pool_kind = ctx.symbols[target.symbol].pool_kind;
        let incoming = builtin_pool_kind(ctx, rhs);
        if pool_kind > 0 && incoming != pool_kind {
            let description = if incoming == 0 { "that is not a pool reference" } else if incoming == 12 { "to a reusable[] pool" } else { "to a reusable pool" };
            error_at(ctx, x.token, str("re-binding ", ctx.tokens[target.token].text, " to a reference ", description, ", where it was bound to a ", if pool_kind == 12 { "reusable[]" } else { "reusable" }, " pool"));
        }
        store_lifetime(ctx, stored, target.symbol, x.token);
        if ctx.types[rhs.ty].kind != T_NULL { ctx.symbols[target.symbol].root = rhs.root; }
        ctx.symbols[target.symbol].growshrink = ctx.symbols[target.symbol].growshrink || rhs.growshrink;
        record_rebind(ctx, target.symbol);
    } else {
        check_stored_view(ctx, stored, x.token);
        // The link is stored in the container the path names.
        store_lifetime(ctx, stored, decay(ctx, value_of(ctx, target.a)).root, x.token);
        record_rebind(ctx, path_root(ctx, x.a));
    }
    ctx.flow = fact_kill(ctx, ctx.flow, x.a, 0);
    if non_null(ctx, rhs) { ctx.flow = fact_add(ctx, ctx.flow, x.a); }
}
recursive fn check_assignment(ctx: Compiler&, n: i64, scope: i64) {
    if ctx.nodes[n].first >= 0 { check_receiving(ctx, n, scope, false); return; }
    let x = ctx.nodes[n];
    if ctx.tokens[x.token].text == ".=" && ctx.nodes[n].flags & 1024 == 0 {
        // In generic code .= on a value slot assigns as = does (spec 3.8).
        let raw = check_expression(ctx, x.a, scope, -1);
        let slot = slot_type(ctx, x.a);
        if (slot < 0 || ctx.types[slot].kind != T_REFERENCE) && generic_code(ctx, ctx.checking_function) { ctx.nodes[n].flags |= 1024; }
        else { check_rebind(ctx, n, scope); return; }
    }
    let raw = check_expression(ctx, x.a, scope, -1); let dest = decay(ctx, raw);
    if dest.place < 0 { error_at(ctx, x.token, "assignment requires a stored value"); }
    let direct = ctx.nodes[x.a].tag == N_NAME && ctx.types[raw.ty].kind != T_REFERENCE;
    var slice_slot = direct && ctx.types[raw.ty].kind == T_SLICE;
    if ctx.types[raw.ty].kind == T_SLICE && (ctx.nodes[x.a].tag == N_MEMBER || ctx.nodes[x.a].tag == N_INDEX) { slice_slot = !ctx.nodes[ctx.nodes[x.a].a].readonly; }
    if dest.readonly && !direct && !slice_slot { error_at(ctx, x.token, "cannot write through read-only storage"); }
    if direct && ctx.symbols[dest.place].flags & 1 == 0 { error_at(ctx, x.token, "cannot reassign a let binding"); }
    // A runtime-capacity limited array keeps its capacity; assignment copies
    // elements into it. Other variable-size values are frozen.
    let dynamic = ctx.types[dest.ty].kind == T_ARRAY && ctx.types[dest.ty].flags == 2;
    if ctx.types[dest.ty].size_class == 1 && !dynamic { error_at(ctx, x.token, "cannot replace a variable-size value"); }
    if ctx.types[dest.ty].size_class == 2 { error_at(ctx, x.token, "not implemented yet: whole resizable assignment analysis"); }
    if ctx.symbols[dest.place].flags & 32 != 0 { error_at(ctx, x.token, "cannot write a by-value iteration binding"); }
    if ctx.nodes[x.a].tag == N_MEMBER && ctx.nodes[x.a].symbol >= 0 && ctx.fielddefs[ctx.nodes[x.a].symbol].flags & 1 != 0 { error_at(ctx, x.token, "cannot reassign a let field"); }
    if x.b >= 0 {
        if ctx.nodes[x.a].tag != N_NAME { ctx.nodes[x.b].standalone = false; }
        let rhs = check_expression(ctx, x.b, scope, dest.ty);
        if !direct { check_stored_view(ctx, received(ctx, rhs, dest.ty), x.token); }
        // A shift's count is any integer, as for << and >> themselves.
        let shift = ctx.tokens[x.token].text == "<<=" || ctx.tokens[x.token].text == ">>=";
        if shift { if ctx.types[dest.ty].kind != T_INTEGER || ctx.types[decay(ctx, rhs).ty].kind != T_INTEGER { error_at(ctx, x.token, "integer shift operands required"); } }
        else { require_fit(ctx, x.b, rhs, dest.ty); }
        store_lifetime(ctx, received(ctx, rhs, dest.ty), if direct { dest.place } else { dest.root }, x.token);
        if direct && ctx.types[dest.ty].kind == T_SLICE && root_depth(ctx, rhs.root) >= root_depth(ctx, ctx.symbols[dest.place].root) { ctx.symbols[dest.place].root = rhs.root; }
        if direct { ctx.symbols[dest.place].growshrink = ctx.symbols[dest.place].growshrink || rhs.growshrink; }
    } else if ctx.types[dest.ty].kind != T_INTEGER { error_at(ctx, x.token, "increment requires an integer"); }
    ctx.flow = fact_kill(ctx, ctx.flow, x.a, 1);
    ctx.symbols[dest.place].known = false;
    // Updating an aggregate invalidates a remembered constructor mapping.
    if ctx.types[dest.ty].kind == T_STRUCT { ctx.symbols[dest.place].fields = -1; }
}
recursive fn check_loop(ctx: Compiler&, n: i64, scope: i64, expected: i64) -> Value {
    let x = ctx.nodes[n];
    ctx.loop_depth++;
    let outer_breaks = ctx.loop_breaks; ctx.loop_breaks = 0;
    let outer_target = ctx.break_target; ctx.break_target = n;
    var tail = Value {};
    let loop_entry = fact_kill_rebinds(ctx, ctx.flow, n);
    ctx.flow = loop_entry;
    if x.tag == N_WHILE {
        require_condition(ctx, x.a, check_expression(ctx, x.a, scope, -1));
        ctx.flow = condition_facts(ctx, x.a, true, loop_entry);
        check_expression(ctx, x.b, scope, 0);
        ctx.flow = condition_facts(ctx, x.a, false, fact_meet(ctx, loop_entry, ctx.flow));
    }
    else if x.tag == N_LOOP || x.tag == N_EARLY {
        ctx.nodes[n].b = -1; ctx.nodes[n].c = expected;
        tail = check_expression(ctx, x.a, scope, if x.tag == N_EARLY { expected } else { 0 });
        ctx.flow = fact_meet(ctx, loop_entry, ctx.flow);
    }
    else {
        let inner = scope_new(ctx, scope, ctx.checking_function);
        var binding_type = default_integer(ctx);
        var root = -1; var held = -1; var loaded_view = false; var growshrink = false;
        // The input is evaluated before the loop catches breaks.
        ctx.break_target = outer_target; ctx.loop_depth--;
        if ctx.nodes[x.b].tag == N_RANGE {
            let a = decay(ctx, check_expression(ctx, ctx.nodes[x.b].a, scope, -1));
            let b = decay(ctx, check_expression(ctx, ctx.nodes[x.b].b, scope, -1));
            binding_type = merge_numeric(ctx, a, b, x.token);
            ctx.nodes[x.b].ty = binding_type;
        } else {
            let iterable = decay(ctx, check_expression(ctx, x.b, scope, -1));
            binding_type = element_type(ctx, iterable.ty); root = iterable.root; held = iterable.held; growshrink = iterable.growshrink;
            if binding_type >= 0 && x.flags & 1 == 0 && (ctx.types[binding_type].kind == T_SLICE || ctx.types[binding_type].kind == T_REFERENCE) { root = iterable.held; loaded_view = true; }
            if binding_type < 0 { binding_type = iterable.ty; if ctx.types[binding_type].kind != T_INTEGER { error_at(ctx, x.token, "for requires an integer or array"); } }
            else if x.flags & 1 != 0 || ctx.types[binding_type].size_class > 0 { binding_type = reference_type(ctx, binding_type, iterable.readonly); }
        }
        ctx.break_target = n; ctx.loop_depth++;
        let s = register_symbol(ctx, ctx.nodes[x.a].token, -1, 2, n, inner, if ctx.types[binding_type].kind == T_REFERENCE { 0 } else { 32 });
        ctx.symbols[s].ty = binding_type; ctx.symbols[s].root = root; ctx.symbols[s].state = 2; ctx.nodes[x.a].symbol = s;
        ctx.symbols[s].held = held; ctx.symbols[s].inexact = loaded_view; ctx.symbols[s].growshrink = growshrink && contains_view(ctx, binding_type);
        if x.first >= 0 {
            let index = ctx.edges[x.first].value; let i = register_symbol(ctx, ctx.nodes[index].token, -1, 2, n, inner, 0);
            ctx.symbols[i].ty = default_integer(ctx); ctx.symbols[i].state = 2; ctx.nodes[index].symbol = i;
        }
        check_expression(ctx, x.c, inner, 0);
        ctx.flow = fact_meet(ctx, loop_entry, ctx.flow);
    }
    ctx.loop_depth--;
    // A loop that no break leaves never completes (6.5): it is as a return.
    let left = ctx.loop_breaks > 0; ctx.loop_breaks = outer_breaks;
    ctx.break_target = outer_target;
    if x.tag == N_LOOP && !left { return Value { ty: intern_type(ctx, Type { kind: T_BOTTOM }) }; }
    let broke = (x.tag == N_LOOP || x.tag == N_EARLY) && ctx.nodes[n].b >= 0;
    // A block's value is its tail's or a break's; a loop's only a break's.
    if x.tag == N_EARLY && !broke { return tail; }
    if x.tag == N_EARLY { return join_branch(ctx, value_of(ctx, n), tail, ctx.nodes[n].b, if ctx.nodes[x.a].a >= 0 { ctx.nodes[x.a].a } else { x.a }, x.token); }
    if broke { return value_of(ctx, n); }
    return Value {};
}
fn check_return(ctx: Compiler&, n: i64, raw: Value, spec: i64, token: i64) {
    if child_count(ctx, ctx.specializations[spec].results) != 1 { error_at(ctx, token, "return result count mismatch"); }
    check_result(ctx, n, raw, spec, first_child(ctx, ctx.specializations[spec].results), token);
}
fn check_result(ctx: Compiler&, n: i64, raw: Value, spec: i64, result: i64, token: i64) {
    var v = raw;
    let own_local = v.place >= 0 && ctx.scopes[ctx.symbols[v.place].scope].function == spec && ctx.types[ctx.symbols[v.place].ty].kind != T_REFERENCE;
    if ctx.nodes[result].ty < 0 {
        let value = decay(ctx, v);
        var inferred = value.ty;
        let explicit_ref = n >= 0 && ctx.nodes[n].tag == N_UNARY && ctx.tokens[ctx.nodes[n].token].text == "&";
        if explicit_ref || (ctx.types[value.ty].size_class > 0 && (ctx.types[v.ty].kind == T_REFERENCE || (v.place >= 0 && !own_local))) { inferred = reference_type(ctx, value.ty, v.readonly); }
        ctx.nodes[result].ty = inferred;
        if result == first_child(ctx, ctx.specializations[spec].results) { ctx.specializations[spec].result = inferred; }
    }
    let target = ctx.nodes[result].ty;
    if ctx.types[target].kind != T_REFERENCE { v = decay(ctx, v); }
    if ctx.types[target].size_class > 0 && !adapts_enum(ctx, decay(ctx, v).ty, target) && v.place >= 0 && !own_local { error_at(ctx, token, "returning nonfixed storage by value requires an explicit copy"); }
    let decl = ctx.symbols[ctx.specializations[spec].symbol].decl;
    if ctx.specializations[spec].in_cycle && ctx.nodes[decl].b < 0 && ctx.types[target].kind == T_REFERENCE { error_at(ctx, token, "a recursive cycle needs an explicit reference result type"); }
    if n >= 0 {
        // Results are generic over constness: a read-only view returned where
        // a writable one is declared makes this instance's result read-only.
        var given = v;
        let t = ctx.types[target]; let g = ctx.types[given.ty];
        if (t.kind == T_SLICE || t.kind == T_REFERENCE) && t.flags & 1 == 0 {
            if g.kind == t.kind && g.element == t.element && g.flags & 1 != 0 { given.ty = target; given.readonly = true; }
            if t.kind == T_REFERENCE { given.readonly = false; }
        }
        require_fit(ctx, n, given, target);
    }
    else if target != 0 { error_at(ctx, token, "missing return value"); }
    let root = content_root(ctx, received(ctx, v, target));
    if contains_view(ctx, target) && root >= 0 && ctx.scopes[ctx.symbols[root].scope].function == spec { error_at(ctx, token, "returned reference refers to a local"); }
    if contains_view(ctx, target) && ctx.nodes[result].flags & 2 != 0 {
        if root_depth(ctx, root) > root_depth(ctx, ctx.nodes[result].root) || (v.growshrink && !ctx.nodes[result].growshrink) { error_at(ctx, token, "return weakens the provenance already used by a recursive call"); }
        if root != ctx.nodes[result].root && v.inexact && v.place >= 0 && ctx.symbols[v.place].scope != 0 && ctx.scopes[ctx.symbols[v.place].scope].function != spec { error_at(ctx, token, "not implemented yet: recursive result gains a captured inexact reference"); }
    }
    // Each return must be safe on its own. A merged result is bounded by
    // the innermost owner, rather than forcing all paths to one arena.
    if root >= 0 && root_depth(ctx, root) >= root_depth(ctx, ctx.nodes[result].root) { ctx.nodes[result].root = root; }
    if ctx.nodes[result].flags & 1 == 0 { ctx.nodes[result].fields = v.fields; }
    else if ctx.nodes[result].fields != v.fields { ctx.nodes[result].fields = -1; }
    ctx.nodes[result].flags |= 1;
    ctx.nodes[result].readonly = ctx.nodes[result].readonly || v.readonly;
    ctx.nodes[result].growshrink = ctx.nodes[result].growshrink || v.growshrink;
    ctx.nodes[result].inexact = ctx.nodes[result].inexact || v.inexact;
}

// The current C backend gives empty structs/arrays a padding byte. Do not
// expose that placeholder as a serialized language value.
recursive fn builtin_image_safe(ctx: Compiler&, ty: i64) -> bool {
    let t = ctx.types[ty];
    if t.kind == T_SLICE || t.size_class == 3 { return false; }
    if t.kind == T_REFERENCE { return t.flags & 8 != 0; }
    if t.kind == T_ARRAY { return builtin_image_safe(ctx, t.element); }
    if t.kind == T_STRUCT {
        var e = t.first; while e >= 0 { if !builtin_image_safe(ctx, ctx.fielddefs[ctx.edges[e].value].ty) { return false; } e = ctx.edges[e].next; }
    }
    if t.kind == T_ENUM {
        var e = t.first; while e >= 0 { if !builtin_image_safe(ctx, ctx.edges[e].value) { return false; } e = ctx.edges[e].next; }
    }
    return true;
}
recursive fn image_layout_supported(ctx: Compiler&, ty: i64) -> bool {
    let t = ctx.types[ty];
    if t.kind == T_ARRAY { return t.count != 0 && image_layout_supported(ctx, t.element); }
    if t.kind == T_STRUCT {
        if t.first < 0 { return false; }
        var e = t.first;
        while e >= 0 { if !image_layout_supported(ctx, ctx.fielddefs[ctx.edges[e].value].ty) { return false; } e = ctx.edges[e].next; }
    }
    if t.kind == T_ENUM {
        var e = t.first;
        while e >= 0 { let vt = ctx.edges[e].value; if ctx.types[vt].first >= 0 && !image_layout_supported(ctx, vt) { return false; } e = ctx.edges[e].next; }
    }
    return true;
}

// Build a checked default tree once; the emitter executes it once per new
// slice element, so field defaults with side effects keep their semantics.
recursive fn pool_default_expression(ctx: Compiler&, ty: i64, token: i64, scope: i64) -> i64 {
    let t = ctx.types[ty];
    if t.kind == T_REFERENCE && !is_optional(ctx, ty) { error_at(ctx, token, "slice pool element has no default: reference"); }
    if t.kind == T_ENUM {
        if t.first < 0 { error_at(ctx, token, "slice pool element has no default: empty enum"); }
        return pool_default_expression(ctx, ctx.edges[t.first].value, token, scope);
    }
    if t.kind == T_ARRAY && t.flags == 0 && t.count > 0 {
        let init = pool_default_expression(ctx, t.element, token, scope);
        let n = node(ctx, N_FILL, token); ctx.nodes[n].a = init; ctx.nodes[n].flags = 4096;
        annotate(ctx, n, Value { ty: ty, held: content_root(ctx, value_of(ctx, init)) }); return n;
    }
    if t.kind != T_STRUCT { return type_default_value(ctx, ty, token); }
    let n = node(ctx, N_CONSTRUCT, token); var root = -1; var e = t.first;
    while e >= 0 {
        let field = ctx.edges[e].value; let f = ctx.fielddefs[field];
        let defaults = ctx.default_stack; let mark = defaults.len;
        for entry in defaults { if entry == -2 - field { error_at(ctx, token, "cyclic slice pool element default"); } }
        defaults.push(-2 - field);
        var init = -1;
        if f.initializer >= 0 {
            init = clone_tree(ctx, f.initializer); check_expression(ctx, init, t.scope, f.ty);
        } else { init = pool_default_expression(ctx, f.ty, token, scope); }
        defaults.resize(mark);
        let v = value_of(ctx, init); require_fit(ctx, init, v, f.ty);
        let stored = received(ctx, v, f.ty); check_stored_view(ctx, stored, token);
        if root_depth(ctx, content_root(ctx, stored)) > root_depth(ctx, root) { root = content_root(ctx, stored); }
        let added = node(ctx, N_INIT, f.token); ctx.nodes[added].a = init; ctx.nodes[added].symbol = field; child(ctx, n, added);
        e = ctx.edges[e].next;
    }
    annotate(ctx, n, Value { ty: ty, held: root, fields: ctx.nodes[n].first }); return n;
}
recursive fn builtin_array_count(ctx: Compiler&, ty: i64, element: i64) -> i64 {
    if ty == element { return 2; } // A matching scalar outside the array makes the root ambiguous.
    let t = ctx.types[ty];
    if t.kind == T_ARRAY {
        if t.element == element { return 1; }
        let nested = builtin_array_count(ctx, t.element, element);
        if nested == 0 { return 0; }
        if t.flags == 0 && t.count == 1 { return nested; }
        return 2;
    }
    var count = 0;
    if t.kind == T_STRUCT {
        var e = t.first; while e >= 0 { count += builtin_array_count(ctx, ctx.fielddefs[ctx.edges[e].value].ty, element); e = ctx.edges[e].next; }
    }
    return count;
}
recursive fn builtin_owns_element(ctx: Compiler&, ty: i64, element: i64) -> bool {
    if ty == element { return true; }
    let t = ctx.types[ty];
    if t.kind == T_ARRAY { return builtin_owns_element(ctx, t.element, element); }
    if t.kind == T_STRUCT {
        var e = t.first; while e >= 0 { if builtin_owns_element(ctx, ctx.fielddefs[ctx.edges[e].value].ty, element) { return true; } e = ctx.edges[e].next; }
    }
    if t.kind == T_ENUM {
        var e = t.first; while e >= 0 { if builtin_owns_element(ctx, ctx.edges[e].value, element) { return true; } e = ctx.edges[e].next; }
    }
    return false;
}
fn builtin_unique_global(ctx: Compiler&, array: Value, value: Value, element: i64) -> bool {
    if value.readonly || array.root < 0 || ctx.symbols[array.root].scope != 0 || value.root != array.root { return false; }
    for s, i in ctx.symbols {
        if i != array.root && s.kind == 2 && s.scope == 0 && s.ty >= 0 && builtin_owns_element(ctx, s.ty, element) { return false; }
    }
    return true;
}
fn builtin_pool_kind(ctx: Compiler&, v: Value) -> i64 {
    if is_optional(ctx, v.ty) || v.inexact { return 0; }
    if v.place >= 0 && ctx.types[ctx.symbols[v.place].ty].kind == T_REFERENCE { return ctx.symbols[v.place].pool_kind; }
    if v.root >= 0 { return ctx.symbols[v.root].flags & 12; }
    return 0;
}
recursive fn check_builtin_argument(ctx: Compiler&, call: i64, arg: i64, scope: i64, expected: i64) -> Value {
    if ctx.nodes[call].flags & 512 != 0 || (arg == first_child(ctx, call) && ctx.nodes[call].flags & 256 != 0) { return value_of(ctx, arg); }
    return check_expression(ctx, arg, scope, expected);
}
recursive fn check_call(ctx: Compiler&, n: i64, scope: i64) -> Value {
    let callee = ctx.nodes[n].a;
    let member = ctx.nodes[callee].tag == N_MEMBER;
    let name = ctx.tokens[ctx.nodes[callee].token].text;
    let new_builtin = name == "alloc_slice" || name == "free_slice" || name == "realloc_slice" || name == "free" || name == "alloc_index" || name == "alloc_ref" || name == "move_from" || name == "index_of" || name == "bytes_of" || name == "check_length" || name == "range_index";
    var receiver = Value {};
    if !member && name == "pop_n" && lookup(ctx, callee, scope, 3) < 0 {
        if child_count(ctx, n) != 2 { error_at(ctx, ctx.nodes[n].token, "pop_n takes an array and count"); }
        let first = ctx.nodes[n].first;
        let method = node(ctx, N_MEMBER, ctx.nodes[callee].token);
        ctx.nodes[method].a = ctx.edges[first].value; ctx.nodes[method].first = ctx.nodes[callee].first;
        ctx.nodes[n].a = method; ctx.nodes[n].first = ctx.edges[first].next;
        return check_call(ctx, n, scope);
    }
    if name == "pop_n" && ctx.nodes[callee].first >= 0 { error_at(ctx, ctx.nodes[n].token, "builtin takes no type arguments"); }
    let array_method = member && (name == "push" || name == "append" || name == "resize" || name == "clear" || name == "pop" || name == "pop_n" || new_builtin);
    if array_method { receiver = check_expression(ctx, ctx.nodes[callee].a, scope, -1); }
    // Builtin arguments are checked with their construction destination.
    if member && element_type(ctx, receiver.ty) >= 0 {
        let array = decay(ctx, receiver); let element = element_type(ctx, array.ty);
        if name == "push" || name == "append" || name == "resize" || name == "clear" || name == "pop" || name == "pop_n" {
            let shrinking = name == "resize" || name == "clear" || name == "pop" || name == "pop_n";
            // References into a limited array stay valid across shrinks.
            let limited = ctx.types[array.ty].kind == T_ARRAY && ctx.types[array.ty].flags == 2;
            if (name == "pop" || name == "pop_n" || name == "resize") && ctx.types[element].size_class != 0 { error_at(ctx, ctx.nodes[callee].token, str(".", name, " needs fixed-size elements: the array is sequential")); }
            if shrinking && !limited && !ctx.nodes[n].standalone { error_at(ctx, ctx.nodes[n].token, "not implemented yet: shrinking within a larger expression"); }
            if array.readonly { error_at(ctx, ctx.nodes[callee].token, "cannot mutate a read-only array"); }
            if ctx.types[array.ty].kind != T_ARRAY || ctx.types[array.ty].flags < 2 { error_at(ctx, ctx.nodes[callee].token, "operation requires a growable array"); }
            var e = ctx.nodes[n].first;
            if name == "push" {
                if child_count(ctx, n) != 1 { error_at(ctx, ctx.nodes[n].token, "push takes one element"); }
                let arg = ctx.edges[e].value; let v = check_expression(ctx, arg, scope, element); require_fit(ctx, arg, v, element); store_in_array(ctx, received(ctx, v, element), array, scope, ctx.nodes[n].token);
                ctx.nodes[n].symbol = -10; return Value { ty: reference_type(ctx, element, false), root: array.root, place: array.place };
            }
            if name == "append" {
                if child_count(ctx, n) != 1 { error_at(ctx, ctx.nodes[n].token, "append takes one array or slice"); }
                let arg = ctx.edges[e].value; let v = decay(ctx, check_expression(ctx, arg, scope, array_type(ctx, element, 3, -1)));
                if element_type(ctx, v.ty) != element { error_at(ctx, ctx.nodes[arg].token, "append element type mismatch"); }
                if ctx.types[v.ty].size_class == 2 && v.place < 0 { error_at(ctx, ctx.nodes[arg].token, "not implemented yet: constructed append result analysis"); }
                store_in_array(ctx, Value { ty: element, root: v.held, held: v.held }, array, scope, ctx.nodes[n].token); ctx.nodes[n].symbol = -11;
            } else if name == "resize" {
                if child_count(ctx, n) < 1 || child_count(ctx, n) > 2 { error_at(ctx, ctx.nodes[n].token, "resize takes a length and optional fill"); }
                let count = ctx.edges[e].value; require_fit(ctx, count, decay(ctx, check_expression(ctx, count, scope, -1)), default_integer(ctx)); e = ctx.edges[e].next;
                var balanced = false;
                if ctx.types[array.ty].flags == 4 && ctx.nodes[count].tag == N_NAME {
                    let mark = ctx.symbols[ctx.nodes[count].symbol];
                    balanced = mark.length_root == array.root && ctx.scopes[mark.scope].function == ctx.checking_function && stable_array_path(ctx, ctx.nodes[callee].a);
                }
                shrink_array(ctx, array, scope, ctx.nodes[n].token, balanced);
                if e >= 0 { let fill = ctx.edges[e].value; require_fit(ctx, fill, check_expression(ctx, fill, scope, element), element); }
                ctx.nodes[n].symbol = -12;
            } else if name == "clear" { shrink_array(ctx, array, scope, ctx.nodes[n].token, false); if child_count(ctx, n) != 0 { error_at(ctx, ctx.nodes[n].token, "clear takes no arguments"); } ctx.nodes[n].symbol = -13; }
            else if name == "pop_n" {
                if child_count(ctx, n) != 1 { error_at(ctx, ctx.nodes[n].token, "pop_n takes a count"); }
                let count = ctx.edges[e].value; require_fit(ctx, count, decay(ctx, check_expression(ctx, count, scope, -1)), default_integer(ctx));
                shrink_array(ctx, array, scope, ctx.nodes[n].token, false); ctx.nodes[n].symbol = -15;
            }
            else { shrink_array(ctx, array, scope, ctx.nodes[n].token, false); if child_count(ctx, n) != 0 { error_at(ctx, ctx.nodes[n].token, "pop takes no arguments"); } ctx.nodes[n].symbol = -14; return Value { ty: element }; }
            return Value {};
        }
    }
    if !member && (name == "print" || name == "str" || name == "format") {
        var e = ctx.nodes[n].first;
        if name == "format" {
            if e < 0 { error_at(ctx, ctx.nodes[n].token, "format needs a destination"); }
            let out = decay(ctx, check_expression(ctx, ctx.edges[e].value, scope, -1));
            if element_type(ctx, out.ty) != integer_type(ctx, 1, true) || out.readonly { error_at(ctx, ctx.nodes[n].token, "format needs a writable byte builder"); }
            e = ctx.edges[e].next;
        }
        while e >= 0 { prepare_rendering(ctx, decay(ctx, check_expression(ctx, ctx.edges[e].value, scope, -1)).ty, ctx.nodes[n].token); e = ctx.edges[e].next; }
        if name == "str" { ctx.nodes[n].symbol = -21; return Value { ty: array_type(ctx, integer_type(ctx, 1, true), 3, -1) }; }
        if name == "print" { ctx.nodes[n].symbol = -20; } else { ctx.nodes[n].symbol = -22; }
        return Value {};
    }
    if !member && (name == "src_file" || name == "src_line") && lookup(ctx, callee, scope, 3) < 0 {
        if child_count(ctx, n) != 0 { error_at(ctx, ctx.nodes[n].token, str(name, " takes no arguments")); }
        var site = ctx.nodes[n].token; if ctx.default_site >= 0 { site = ctx.default_site; }
        // The site's token stays in the value's bits for the emitter.
        if name == "src_line" { ctx.nodes[n].symbol = -28; return Value { ty: default_integer(ctx), bits: site as u64 }; }
        ctx.nodes[n].symbol = -29; return Value { ty: slice_type(ctx, integer_type(ctx, 1, true), true), readonly: true, bits: site as u64 };
    }
    if !member && (name == "assert" || name == "abort" || name == "exit" || name == "copy" || name == "default") {
        if name == "default" {
            let t = first_child(ctx, callee); if t < 0 { error_at(ctx, ctx.nodes[n].token, "default requires a type argument"); }
            let ty = resolve_type(ctx, t, scope); ctx.nodes[n].symbol = -27; return Value { ty: ty };
        }
        if child_count(ctx, n) != 1 { error_at(ctx, ctx.nodes[n].token, "builtin takes one argument"); }
        let arg = first_child(ctx, n); let raw = check_expression(ctx, arg, scope, -1); let v = decay(ctx, raw);
        if name == "assert" { require_condition(ctx, arg, raw); ctx.flow = condition_facts(ctx, arg, true, ctx.flow); ctx.nodes[n].symbol = -23; return Value {}; }
        if name == "copy" { if (v.place < 0 && ctx.types[raw.ty].kind != T_REFERENCE) || ctx.types[v.ty].kind == T_SLICE { error_at(ctx, ctx.nodes[arg].token, "copy requires an owned stored value or its reference"); } ctx.nodes[n].symbol = -26; var result = v; result.place = -1; result.readonly = false; return result; }
        if name == "exit" { require_fit(ctx, arg, v, default_integer(ctx)); ctx.nodes[n].symbol = -25; }
        else { if element_type(ctx, v.ty) != integer_type(ctx, 1, true) { error_at(ctx, ctx.nodes[n].token, "abort requires text"); } ctx.nodes[n].symbol = -24; }
        return Value { ty: intern_type(ctx, Type { kind: T_BOTTOM }) };
    }
    if member {
        // Lower UFCS once to a normal call. The receiver stays first, so both
        // type checking and generated evaluation keep source argument order.
        let function = node(ctx, N_NAME, ctx.nodes[callee].token);
        ctx.nodes[function].ns = ctx.nodes[callee].ns;
        ctx.nodes[function].first = ctx.nodes[callee].first; ctx.nodes[function].last = ctx.nodes[callee].last;
        let edge = ctx.edges.len;
        ctx.edges.push(Edge { value: ctx.nodes[callee].a, next: ctx.nodes[n].first });
        ctx.nodes[n].first = edge; if ctx.nodes[n].last < 0 { ctx.nodes[n].last = edge; }
        ctx.nodes[n].a = function;
        if array_method { ctx.nodes[n].flags |= 256; if ctx.types[decay(ctx, receiver).ty].kind == T_ARRAY { ctx.nodes[n].flags |= 1024; } }
        return check_call(ctx, n, scope);
    }
    var preferred = -1;
    let user_function = lookup(ctx, callee, scope, 3);
    if new_builtin && user_function >= 0 && ctx.nodes[n].flags & 1024 == 0 {
        preferred = resolve_overload_or_builtin(ctx, user_function, n, scope, true);
        if preferred == -2 { return check_dispatch(ctx, n, scope); }
    }
    if preferred < 0 && (name == "alloc_slice" || name == "free_slice" || name == "realloc_slice") {
        if ctx.nodes[callee].first >= 0 { error_at(ctx, ctx.nodes[n].token, "builtin takes no type arguments"); }
        let count = if name == "realloc_slice" { 3 } else { 2 };
        if child_count(ctx, n) != count { error_at(ctx, ctx.nodes[n].token, "slice pool argument count mismatch"); }
        var e = ctx.nodes[n].first; let recv = ctx.edges[e].value;
        let pool = decay(ctx, check_builtin_argument(ctx, n, recv, scope, -1));
        let element = element_type(ctx, pool.ty);
        if element < 0 || ctx.types[pool.ty].kind != T_ARRAY || ctx.types[pool.ty].flags != 3 || pool.root < 0 || pool.inexact { error_at(ctx, ctx.nodes[recv].token, "operation requires an exact reusable[] pool"); }
        if builtin_pool_kind(ctx, value_of(ctx, recv)) != 12 { error_at(ctx, ctx.nodes[recv].token, "operation exists on reusable[] slice pools only"); }
        if pool.readonly { error_at(ctx, ctx.nodes[recv].token, "cannot mutate a read-only pool"); }
        if ctx.types[element].size_class != 0 { error_at(ctx, ctx.nodes[recv].token, "pool requires fixed-size elements"); }
        reference_type(ctx, pool.ty, false); e = ctx.edges[e].next;
        if name != "alloc_slice" {
            let arg = ctx.edges[e].value; let value = decay(ctx, check_builtin_argument(ctx, n, arg, scope, -1));
            if ctx.types[value.ty].kind != T_SLICE || element_type(ctx, value.ty) != element { error_at(ctx, ctx.nodes[arg].token, "operation requires a slice of the pool element type"); }
            if value.root >= 0 && value.root != pool.root && !value.inexact {
                let own = ctx.symbols[value.root].scope == 0 || ctx.scopes[ctx.symbols[value.root].scope].function == ctx.checking_function;
                let pool_own = ctx.symbols[pool.root].scope == 0 || ctx.scopes[ctx.symbols[pool.root].scope].function == ctx.checking_function;
                if own && pool_own { error_at(ctx, ctx.nodes[arg].token, "operation needs a slice of the pool it is called on"); }
            }
            e = ctx.edges[e].next;
        }
        if name == "free_slice" { ctx.nodes[n].symbol = BI_FREE_SLICE; return Value {}; }
        let count_node = ctx.edges[e].value; let length = decay(ctx, check_builtin_argument(ctx, n, count_node, scope, -1));
        if ctx.types[length.ty].kind != T_INTEGER { error_at(ctx, ctx.nodes[count_node].token, "slice pool length must be an integer"); }
        if name == "realloc_slice" && holds_self_relative(ctx, element) { error_at(ctx, ctx.nodes[n].token, "realloc_slice cannot move elements containing self-relative references"); }
        let init = pool_default_expression(ctx, element, ctx.nodes[n].token, scope);
        ctx.nodes[n].b = init;
        store_in_array(ctx, received(ctx, value_of(ctx, init), element), pool, scope, ctx.nodes[n].token);
        ctx.nodes[n].symbol = if name == "alloc_slice" { BI_ALLOC_SLICE } else { BI_REALLOC_SLICE };
        return Value { ty: slice_type(ctx, element, false), root: pool.root, held: ctx.symbols[pool.root].held };
    }
    if preferred < 0 && (name == "free" || name == "alloc_index" || name == "alloc_ref") {
        if ctx.nodes[callee].first >= 0 { error_at(ctx, ctx.nodes[n].token, "builtin takes no type arguments"); }
        if child_count(ctx, n) != 2 { error_at(ctx, ctx.nodes[n].token, "pool operation takes a pool and one argument"); }
        let e = ctx.nodes[n].first; let recv = ctx.edges[e].value;
        let pool = decay(ctx, check_builtin_argument(ctx, n, recv, scope, -1));
        let element = element_type(ctx, pool.ty);
        if element < 0 || ctx.types[pool.ty].kind != T_ARRAY || ctx.types[pool.ty].flags != 3 || pool.root < 0 || pool.inexact { error_at(ctx, ctx.nodes[recv].token, "operation requires an exact reusable pool"); }
        if builtin_pool_kind(ctx, value_of(ctx, recv)) != 4 { error_at(ctx, ctx.nodes[recv].token, "operation exists on reusable slot pools only"); }
        if pool.readonly { error_at(ctx, ctx.nodes[recv].token, "cannot mutate a read-only pool"); }
        if ctx.types[element].size_class != 0 { error_at(ctx, ctx.nodes[recv].token, "pool requires fixed-size elements"); }
        reference_type(ctx, pool.ty, false);
        let arg = ctx.edges[ctx.edges[e].next].value;
        if name == "free" {
            let value = decay(ctx, check_builtin_argument(ctx, n, arg, scope, -1));
            if ctx.types[value.ty].kind != T_INTEGER { error_at(ctx, ctx.nodes[arg].token, "free requires an integer index"); }
            ctx.nodes[n].symbol = BI_FREE; return Value {};
        }
        let value = check_builtin_argument(ctx, n, arg, scope, element); require_fit(ctx, arg, value, element);
        store_in_array(ctx, received(ctx, value, element), pool, scope, ctx.nodes[n].token);
        if name == "alloc_index" { ctx.nodes[n].symbol = BI_ALLOC_INDEX; return Value { ty: default_integer(ctx) }; }
        ctx.nodes[n].symbol = BI_ALLOC_REF;
        if ctx.types[element].kind == T_REFERENCE { let stored = received(ctx, value, element); return Value { ty: plain_reference(ctx, element), root: stored.root, readonly: stored.readonly, held: stored.held }; }
        return Value { ty: reference_type(ctx, element, false), root: pool.root, place: pool.place };
    }
    if preferred < 0 && (name == "move_from" || name == "index_of" || name == "bytes_of") {
        if ctx.nodes[callee].first >= 0 { error_at(ctx, ctx.nodes[n].token, "builtin takes no type arguments"); }
        let argc = if name == "bytes_of" { 1 } else { 2 };
        if child_count(ctx, n) != argc { error_at(ctx, ctx.nodes[n].token, "builtin argument count mismatch"); }
        let e = ctx.nodes[n].first; let recv = ctx.edges[e].value;
        let array = decay(ctx, check_builtin_argument(ctx, n, recv, scope, -1));
        let element = element_type(ctx, array.ty);
        if element < 0 { error_at(ctx, ctx.nodes[recv].token, "operation requires an array or slice"); }
        if ctx.types[element].size_class != 0 { error_at(ctx, ctx.nodes[recv].token, "operation requires fixed-size elements"); }
        if name == "bytes_of" {
            if !builtin_image_safe(ctx, element) { error_at(ctx, ctx.nodes[recv].token, "bytes_of cannot expose elements containing addresses or external pool references"); }
            if !image_layout_supported(ctx, element) { error_at(ctx, ctx.nodes[recv].token, "not implemented yet: byte images containing zero-size storage"); }
            if array.root >= 0 && ctx.symbols[array.root].kind == 4 { error_at(ctx, ctx.nodes[recv].token, "bytes_of requires persistent storage"); }
            if array.root >= 0 { ctx.symbols[array.root].byteviewed = true; }
            if array.inexact {
                for owner, i in ctx.symbols {
                    if owner.kind == 2 && root_depth(ctx, i) <= root_depth(ctx, array.root) { ctx.symbols[i].byteviewed = true; }
                }
            }
            ctx.nodes[n].symbol = BI_BYTES_OF;
            return Value { ty: slice_type(ctx, integer_type(ctx, 1, true), true), root: array.root, readonly: true, growshrink: array.growshrink || (ctx.types[array.ty].kind == T_ARRAY && ctx.types[array.ty].flags == 4), inexact: array.inexact };
        }
        let arg = ctx.edges[ctx.edges[e].next].value;
        let raw = check_builtin_argument(ctx, n, arg, scope, -1); let value = decay(ctx, raw);
        if name == "move_from" {
            if holds_self_relative(ctx, element) { error_at(ctx, ctx.nodes[n].token, "move_from cannot copy elements containing self-relative references"); }
            if ctx.types[array.ty].kind != T_SLICE { error_at(ctx, ctx.nodes[recv].token, "move_from requires a destination slice"); }
            if array.readonly { error_at(ctx, ctx.nodes[recv].token, "cannot mutate a read-only slice"); }
            if ctx.types[value.ty].kind != T_SLICE || element_type(ctx, value.ty) != element { error_at(ctx, ctx.nodes[arg].token, "move_from requires a slice of the same element type"); }
            store_in_array(ctx, Value { ty: element, root: value.held, growshrink: value.growshrink, held: value.held }, array, scope, ctx.nodes[n].token);
            ctx.nodes[n].symbol = BI_MOVE_FROM; return Value {};
        }
        if ctx.types[array.ty].kind != T_ARRAY || ctx.types[array.ty].flags == 1 { error_at(ctx, ctx.nodes[recv].token, "index_of requires an indexable array"); }
        if value.ty != element || (raw.place < 0 && ctx.types[raw.ty].kind != T_REFERENCE) { error_at(ctx, ctx.nodes[arg].token, "index_of requires a reference to an array element"); }
        var origin = value;
        if ctx.types[element].kind == T_SLICE && ctx.nodes[arg].tag == N_INDEX {
            let holder = decay(ctx, value_of(ctx, ctx.nodes[arg].a));
            origin.root = holder.root; origin.inexact = holder.inexact;
        }
        if array.root < 0 || array.root != origin.root || array.inexact || (origin.inexact && !builtin_unique_global(ctx, array, origin, element)) { error_at(ctx, ctx.nodes[arg].token, "index_of needs a reference rooted at the array itself"); }
        let owner = decay(ctx, Value { ty: ctx.symbols[array.root].ty });
        if builtin_array_count(ctx, owner.ty, element) != 1 { error_at(ctx, ctx.nodes[arg].token, "index_of requires a root containing one array of this element type"); }
        reference_type(ctx, array.ty, false); reference_type(ctx, element, false);
        ctx.nodes[n].symbol = BI_INDEX_OF; return Value { ty: default_integer(ctx) };
    }
    if preferred < 0 && (name == "check_length" || name == "range_index") {
        if ctx.nodes[callee].first >= 0 { error_at(ctx, ctx.nodes[n].token, "builtin takes no type arguments"); }
        let count = child_count(ctx, n);
        if count < 2 || count > 3 { error_at(ctx, ctx.nodes[n].token, "builtin argument count mismatch"); }
        var e = ctx.nodes[n].first;
        let array = decay(ctx, check_builtin_argument(ctx, n, ctx.edges[e].value, scope, -1));
        let element = element_type(ctx, array.ty);
        reference_type(ctx, array.ty, false);
        if element < 0 || ctx.types[array.ty].kind != T_ARRAY { error_at(ctx, ctx.nodes[n].token, "operation requires an array"); }
        if ctx.types[element].size_class != 0 { error_at(ctx, ctx.nodes[n].token, str(".", name, " needs fixed-size elements")); }
        if name == "range_index" && ctx.types[array.ty].flags == 1 { error_at(ctx, ctx.nodes[n].token, "range_index requires an indexable array"); }
        if name != "range_index" && ctx.types[array.ty].flags < 3 { error_at(ctx, ctx.nodes[n].token, "operation requires a growable array"); }
        e = ctx.edges[e].next;
        let arg = ctx.edges[e].value;
        let v = decay(ctx, check_builtin_argument(ctx, n, arg, scope, -1));
        if name == "range_index" {
            if ctx.types[v.ty].kind != T_SLICE || element_type(ctx, v.ty) != element { error_at(ctx, ctx.nodes[arg].token, "range_index requires a slice of the array element type"); }
            ctx.nodes[n].symbol = BI_RANGE_INDEX;
        } else {
            if ctx.types[v.ty].kind != T_INTEGER { error_at(ctx, ctx.nodes[arg].token, "count must be an integer"); }
            ctx.nodes[n].symbol = BI_CHECK_LENGTH;
        }
        e = ctx.edges[e].next;
        if e >= 0 {
            let msg = ctx.edges[e].value;
            let text = check_builtin_argument(ctx, n, msg, scope, -1);
            if ctx.nodes[msg].tag != N_STRING { error_at(ctx, ctx.nodes[msg].token, "abort message must be a string literal"); }
        }
        return Value { ty: default_integer(ctx) };
    }
    let s = lookup(ctx, callee, scope, 3);
    if s < 0 { error_at(ctx, ctx.nodes[callee].token, str("unknown function '", name, "'")); }
    if ctx.symbols[s].scope != 0 && ctx.symbols[s].state != 2 { error_at(ctx, ctx.nodes[callee].token, "nested function called before its declaration is reached"); }
    let concrete = if preferred >= 0 { preferred } else { resolve_overload(ctx, s, n, scope) };
    if concrete == -2 { return check_dispatch(ctx, n, scope); }
    fill_defaults(ctx, concrete, n);
    let spec = check_function(ctx, concrete, n, scope);
    var rebound = ctx.specializations[spec].rebinds;
    while rebound >= 0 { let g = ctx.edges[rebound].value; ctx.flow = fact_kill(ctx, ctx.flow, g, 3); record_rebind(ctx, g); rebound = ctx.edges[rebound].next; }
    ctx.checked_calls.push(CheckedCall { node: n, scope: scope, callee: spec });
    var effect = ctx.specializations[spec].shrinks;
    while effect >= 0 {
        let shrink = ctx.shrinks[ctx.edges[effect].value];
        if !shrink.balanced && !ctx.nodes[n].standalone { error_at(ctx, ctx.nodes[n].token, "not implemented yet: call that shrinks within a larger expression"); }
        check_shrink(ctx, shrink.root, shrink.element, scope, ctx.nodes[n].token, shrink.balanced, true);
        effect = ctx.edges[effect].next;
    }
    ctx.nodes[n].symbol = spec;
    return result_value(ctx, first_child(ctx, ctx.specializations[spec].results));
}
// Each case is checked as a call whose dispatched argument is the variant's
// payload, a copy of the enum's; the cases' results must agree (§8.2).
recursive fn check_dispatch(ctx: Compiler&, n: i64, scope: i64) -> Value {
    let place = ctx.nodes[n].b;
    var result = -1;
    var cases = ctx.nodes[n].c;
    while cases >= 0 {
        let symbol = ctx.edges[cases].value;
        let call = node(ctx, N_CALL, ctx.nodes[n].token); ctx.nodes[call].a = ctx.nodes[n].a; ctx.nodes[call].flags = 512;
        var e = ctx.nodes[n].first; var i = 0;
        var p = ctx.nodes[ctx.nodes[ctx.symbols[symbol].decl].a].first;
        while e >= 0 {
            var arg = ctx.edges[e].value;
            if i == place {
                let enumerated = decay(ctx, value_of(ctx, arg));
                let payload = node(ctx, N_NAME, ctx.nodes[arg].token);
                annotate(ctx, payload, Value { ty: resolve_type(ctx, ctx.nodes[ctx.edges[p].value].a, ctx.symbols[symbol].scope), root: enumerated.root, place: enumerated.place, readonly: enumerated.readonly, held: enumerated.held });
                arg = payload;
            }
            child(ctx, call, arg);
            e = ctx.edges[e].next; p = ctx.edges[p].next; i++;
        }
        let spec = check_function(ctx, symbol, call, scope);
        ctx.checked_calls.push(CheckedCall { node: n, scope: scope, callee: spec });
        let given = ctx.specializations[spec].result;
        if result < 0 { result = given; }
        else if given != result { error_at(ctx, ctx.nodes[n].token, "the case functions of a dispatched call must agree on a result type"); }
        if child_count(ctx, ctx.specializations[spec].results) > 1 || ctx.types[given].size_class != 0 { error_at(ctx, ctx.nodes[n].token, "not implemented yet: dispatch to cases with multiple or nonfixed results"); }
        ctx.edges[cases].value = spec;
        cases = ctx.edges[cases].next;
    }
    ctx.nodes[n].symbol = -40;
    return Value { ty: result };
}
// A call leaving out trailing parameters gets a fresh clone of each one's
// default after its written arguments, in parameter order (§7.1). The
// call's flags keep the written count plus one from bit 16, so the rest are
// checked as defaults; a flag, unlike a node link, survives clone_tree.
fn fill_defaults(ctx: Compiler&, symbol: i64, call: i64) {
    if ctx.nodes[call].flags & 1024 != 0 { return; }
    ctx.nodes[call].flags |= 1024;
    var p = ctx.nodes[ctx.nodes[ctx.symbols[symbol].decl].a].first; var e = ctx.nodes[call].first;
    var written = 0;
    while p >= 0 && e >= 0 { p = ctx.edges[p].next; e = ctx.edges[e].next; written++; }
    if p < 0 { return; }
    if ctx.nodes[call].flags & 128 != 0 { error_at(ctx, ctx.nodes[call].token, "not implemented yet: a trailing block with parameter defaults"); }
    ctx.nodes[call].flags |= (written + 1) << 16;
    while p >= 0 {
        let parameter = ctx.edges[p].value;
        if ctx.nodes[parameter].b < 0 { error_at(ctx, ctx.nodes[call].token, "argument count mismatch"); }
        child(ctx, call, clone_tree(ctx, ctx.nodes[parameter].b));
        p = ctx.edges[p].next;
    }
}
// A default is checked at the call, as the argument written there, so its
// temporaries and block locals belong to the caller. Only the names it
// reads come from the declaration, through the floor lookup redirects.
recursive fn check_default(ctx: Compiler&, n: i64, symbol: i64, parameter: i64, caller_scope: i64, expected: i64, site: i64) -> Value {
    let defaults = ctx.default_stack;
    let token = ctx.nodes[parameter].token;
    var i = defaults.len;
    while i > 0 && defaults[i - 1] != -1 {
        i--;
        if defaults[i] == token { error_at(ctx, ctx.nodes[n].token, str("the default of parameter ", ctx.tokens[token].text, " leads to a call that takes it again")); }
    }
    let mark = defaults.len; defaults.push(token);
    let floor = ctx.default_floor; let outer = ctx.default_scope; let limit = ctx.default_limit; let decl = ctx.default_decl; let param = ctx.default_param;
    let scope = scope_new(ctx, caller_scope, ctx.checking_function);
    ctx.default_floor = scope; ctx.default_scope = ctx.symbols[symbol].scope; ctx.default_limit = ctx.symbols[symbol].capture_limit;
    ctx.default_decl = ctx.symbols[symbol].decl; ctx.default_param = parameter;
    let outer_site = ctx.default_site; ctx.default_site = site;
    let v = check_expression(ctx, n, scope, expected);
    ctx.default_floor = floor; ctx.default_scope = outer; ctx.default_limit = limit; ctx.default_decl = decl; ctx.default_param = param;
    ctx.default_site = outer_site;
    defaults.resize(mark);
    return v;
}
// An instantiation as diagnostics show it: the type parameters no parameter
// type names, then the parameter types (typecheck.h DumpInstance).
fn instance_text(ctx: Compiler&, symbol: i64, out: u8[>..]&) {
    out.append(ctx.tokens[ctx.symbols[symbol].token].text);
    var template = -1;
    for instance in ctx.function_instances { if instance.symbol == symbol { template = ctx.symbols[instance.template].decl; } }
    let decl = ctx.symbols[symbol].decl;
    if template >= 0 {
        var listed = false; var g = ctx.nodes[template].first;
        while g >= 0 {
            let generic = ctx.edges[g].value;
            var named = false; var p = ctx.nodes[ctx.nodes[template].a].first;
            while p >= 0 { if syntax_names(ctx, ctx.nodes[ctx.edges[p].value].a, ctx.nodes[generic].token) { named = true; } p = ctx.edges[p].next; }
            let s = find_symbol(ctx, ctx.nodes[generic].token, -1, ctx.symbols[symbol].scope, 1);
            if !named && s >= 0 {
                out.append(if listed { ", " } else { "<" }); listed = true;
                format(out, ctx.tokens[ctx.nodes[generic].token].text, " = "); type_text(ctx, ctx.symbols[s].ty, out);
            }
            g = ctx.edges[g].next;
        }
        if listed { out.push('>'); }
    }
    out.push('(');
    var p = ctx.nodes[ctx.nodes[decl].a].first; var comma = false;
    while p >= 0 {
        if comma { out.append(", "); } comma = true;
        type_text(ctx, resolve_type(ctx, ctx.nodes[ctx.edges[p].value].a, ctx.symbols[symbol].scope), out);
        p = ctx.edges[p].next;
    }
    out.push(')');
}
recursive fn syntax_names(ctx: Compiler&, n: i64, token: i64) -> bool {
    if n < 0 { return false; }
    let x = ctx.nodes[n];
    if x.tag == N_TYPE && x.flags & 1 == 0 && same_name(ctx, x.token, token) { return true; }
    if syntax_names(ctx, x.a, token) || syntax_names(ctx, x.b, token) { return true; }
    var e = x.first;
    while e >= 0 { if syntax_names(ctx, ctx.edges[e].value, token) { return true; } e = ctx.edges[e].next; }
    return false;
}
recursive fn check_function(ctx: Compiler&, symbol: i64, call: i64, caller_scope: i64) -> i64 {
    let decl = ctx.symbols[symbol].decl;
    if ctx.nodes[decl].first >= 0 { error_at(ctx, ctx.nodes[decl].token, "not implemented yet: generic functions"); }
    let params = ctx.nodes[decl].a;
    if call >= 0 && child_count(ctx, params) != child_count(ctx, call) { error_at(ctx, ctx.nodes[call].token, "argument count mismatch"); }
    var actual = -1;
    if call >= 0 { actual = ctx.nodes[call].first; }
    var p = ctx.nodes[params].first;
    var index = 0;
    var first_default = -1; if call >= 0 { first_default = (ctx.nodes[call].flags >> 16) - 1; }
    while p >= 0 {
        let parameter = ctx.edges[p].value;
        if ctx.nodes[parameter].a < 0 { error_at(ctx, ctx.nodes[parameter].token, "not implemented yet: inferred parameter types"); }
        let expected = resolve_type(ctx, ctx.nodes[parameter].a, ctx.symbols[symbol].scope);
        if actual >= 0 {
            let arg = ctx.edges[actual].value;
            let v = if first_default >= 0 && index >= first_default { check_default(ctx, arg, symbol, parameter, caller_scope, expected, ctx.nodes[call].token) } else if ctx.nodes[call].flags & 512 != 0 || (actual == ctx.nodes[call].first && ctx.nodes[call].flags & 256 != 0) { value_of(ctx, arg) } else { check_expression(ctx, arg, caller_scope, expected) };
            require_fit(ctx, arg, v, parameter_destination(ctx, expected, ctx.nodes[decl].flags & 2 != 0));
            ctx.nodes[arg].target = expected;
            if ctx.types[expected].size_class > 0 && !adapts_enum(ctx, decay(ctx, v).ty, expected) && v.place >= 0 { error_at(ctx, ctx.nodes[arg].token, "nonfixed value parameter needs a fresh value or explicit copy"); }
            actual = ctx.edges[actual].next;
        }
        p = ctx.edges[p].next; index++;
    }
    // A provisional record closes recursion before the body is checked.
    for existing, i in ctx.specializations {
        if existing.symbol == symbol {
            var same = true;
            var pe = ctx.nodes[existing.parameters].first;
            var ae = -1; if call >= 0 { ae = ctx.nodes[call].first; }
            while pe >= 0 && ae >= 0 {
                let ps = ctx.symbols[ctx.nodes[ctx.edges[pe].value].symbol];
                let av = value_of(ctx, ctx.edges[ae].value);
                if ps.growshrink != av.growshrink && !(existing.state == 1 && !av.growshrink) { same = false; }
                if ctx.types[ps.ty].kind == T_REFERENCE || ctx.types[ps.ty].kind == T_SLICE {
                    if ps.root != av.root { same = false; }
                    if ctx.types[ps.ty].kind == T_REFERENCE && !is_optional(ctx, ps.ty) && ps.pool_kind != builtin_pool_kind(ctx, av) { same = false; }
                    if ctx.types[ps.ty].flags & 1 == 0 && ps.readonly != av.readonly { same = false; }
                } else if contains_view(ctx, ps.ty) && ps.held != av.held {
                    // A holder passed by value can contain longer-lived views
                    // than the body's conservative bound, including literals.
                    // Array references still retain their storage identity.
                    if existing.state != 1 || !root_outlives(ctx, av.held, ps.held) { same = false; }
                }
                pe = ctx.edges[pe].next; ae = ctx.edges[ae].next;
            }
            if !same && existing.state != 1 { continue; }
            if !same && existing.state == 1 { error_at(ctx, ctx.nodes[call].token, "not implemented yet: recursive arguments broaden reference provenance"); }
            if existing.state == 1 && ctx.nodes[decl].flags & 1 == 0 { error_at(ctx, ctx.nodes[decl].token, "recursive cycle requires recursive fn"); }
            if existing.state == 1 {
                var cycle = ctx.checking_function;
                while cycle >= 0 {
                    ctx.specializations[cycle].in_cycle = true;
                    let cycle_decl = ctx.symbols[ctx.specializations[cycle].symbol].decl;
                    if ctx.nodes[cycle_decl].b < 0 && ctx.specializations[cycle].result >= 0 && ctx.types[ctx.specializations[cycle].result].kind == T_REFERENCE { error_at(ctx, ctx.nodes[cycle_decl].token, "a recursive cycle needs an explicit reference result type"); }
                    if cycle == i { break; } cycle = ctx.specializations[cycle].caller;
                }
            }
            if existing.state == 1 && existing.result < 0 { ctx.specializations[i].result = 0; }
            if existing.state == 1 {
                var re = ctx.nodes[existing.results].first;
                while re >= 0 {
                    let r = ctx.edges[re].value;
                    if ctx.nodes[r].ty < 0 { ctx.nodes[r].ty = ctx.specializations[i].result; }
                    if contains_view(ctx, ctx.nodes[r].ty) {
                        if ctx.nodes[r].flags & 1 == 0 { error_at(ctx, ctx.nodes[call].token, "not implemented yet: recursive reference result before a checked return"); }
                        ctx.nodes[r].flags |= 2;
                    }
                    re = ctx.edges[re].next;
                }
            }
            return i;
        }
    }
    var nested = 0;
    for existing in ctx.specializations { if existing.state == 1 && ctx.symbols[existing.symbol].token == ctx.symbols[symbol].token { nested++; } }
    if nested >= 16 && call >= 0 {
        let name = ctx.tokens[ctx.symbols[symbol].token].text;
        var text: u8[>..] = [];
        format(text, "instantiating "); instance_text(ctx, symbol, text);
        format(text, " would put more than 16 specializations of ", name, " in progress on this call path: a recursive call must reach a finite set of instantiations");
        error_at(ctx, ctx.nodes[call].token, text);
    }
    let results = node(ctx, N_BLOCK, ctx.nodes[decl].token);
    if ctx.nodes[decl].b >= 0 {
        var re = ctx.nodes[ctx.nodes[decl].b].first;
        while re >= 0 {
            let r = node(ctx, N_PAD, ctx.nodes[decl].token);
            ctx.nodes[r].ty = resolve_result_type(ctx, ctx.edges[re].value, ctx.symbols[symbol].scope, child_count(ctx, ctx.nodes[decl].b) > 1);
            child(ctx, results, r); re = ctx.edges[re].next;
        }
    } else { child(ctx, results, node(ctx, N_PAD, ctx.nodes[decl].token)); }
    reject_nonfixed_results(ctx, results);
    if child_count(ctx, results) > 1 && ctx.nodes[decl].flags & 2 != 0 { error_at(ctx, ctx.nodes[decl].token, "not implemented yet: extern multiple results"); }
    let result = ctx.nodes[first_child(ctx, results)].ty;
    let id = ctx.specializations.len;
    let scope = scope_new(ctx, ctx.symbols[symbol].scope, id);
    if ctx.scopes[scope].depth <= ctx.scopes[caller_scope].depth { ctx.scopes[scope].depth = ctx.scopes[caller_scope].depth + 1; }
    let body = clone_tree(ctx, ctx.nodes[decl].c);
    let specialized_params = clone_tree(ctx, params);
    ctx.specializations.push(Specialization { symbol: symbol, body: body, scope: scope, result: result, state: 1, results: results, parameters: specialized_params, caller: ctx.checking_function });
    p = ctx.nodes[specialized_params].first; actual = -1; if call >= 0 { actual = ctx.nodes[call].first; }
    while p >= 0 {
        let param = ctx.edges[p].value;
        let s = register_symbol(ctx, ctx.nodes[param].token, -1, 2, param, scope, ctx.nodes[param].flags);
        let ty = resolve_type(ctx, ctx.nodes[param].a, scope); ctx.symbols[s].ty = ty; ctx.symbols[s].state = 2;
        ctx.symbols[s].readonly = syntax_readonly(ctx, ctx.nodes[param].a, scope);
        if actual >= 0 {
            let argument = ctx.nodes[ctx.edges[actual].value];
            ctx.symbols[s].root = argument.root; ctx.symbols[s].held = argument.held; ctx.symbols[s].fields = argument.fields;
            if ctx.types[ty].kind == T_REFERENCE && !is_optional(ctx, ty) { ctx.symbols[s].pool_kind = builtin_pool_kind(ctx, value_of(ctx, ctx.edges[actual].value)); }
            // A by-value holder's fields may differ in another activation.
            if ctx.types[ty].kind != T_REFERENCE && ctx.types[ty].kind != T_SLICE && contains_view(ctx, ty) { ctx.symbols[s].fields = -1; }
            ctx.symbols[s].growshrink = argument.growshrink;
            ctx.symbols[s].inexact = argument.inexact;
            if ctx.types[ty].kind == T_REFERENCE || ctx.types[ty].kind == T_SLICE { ctx.symbols[s].readonly = ctx.symbols[s].readonly || argument.readonly; }
            actual = ctx.edges[actual].next;
        }
        if call < 0 && contains_view(ctx, ty) {
            let own = ctx.symbols.len;
            ctx.symbols.push(Symbol { token: ctx.nodes[param].token, ns: -1, kind: 4, decl: param, scope: 0, ty: ty, state: 2 });
            index_symbol(ctx, own);
            if ctx.types[ty].kind == T_REFERENCE || ctx.types[ty].kind == T_SLICE { ctx.symbols[s].root = own; }
            else { ctx.symbols[s].held = own; }
        }
        ctx.nodes[param].symbol = s; p = ctx.edges[p].next;
    }
    if ctx.nodes[decl].flags & 2 == 0 {
        let previous = ctx.checking_function; let previous_loop = ctx.loop_depth; let previous_breaks = ctx.loop_breaks; let previous_target = ctx.break_target;
        ctx.checking_function = id; ctx.loop_depth = 0; ctx.loop_breaks = 0; ctx.break_target = -1;
        // A body declared outside a default may take that default again,
        // which makes it recursive rather than an endless default (§3.2).
        let defaults = ctx.default_stack; let default_mark = defaults.len; defaults.push(-1);
        let outer_site = ctx.default_site; ctx.default_site = -1;
        let outer_flow = ctx.flow; ctx.flow = -1;
        let tail = check_expression(ctx, body, scope, result);
        ctx.flow = outer_flow;
        if ctx.types[tail.ty].kind != T_BOTTOM { check_return(ctx, ctx.nodes[body].a, tail, id, ctx.nodes[decl].token); }
        defaults.resize(default_mark); ctx.default_site = outer_site;
        ctx.checking_function = previous; ctx.loop_depth = previous_loop; ctx.loop_breaks = previous_breaks; ctx.break_target = previous_target;
    } else if result < 0 { ctx.specializations[id].result = 0; }
    if ctx.specializations[id].result < 0 { ctx.specializations[id].result = 0; }
    if ctx.nodes[first_child(ctx, results)].ty < 0 { ctx.nodes[first_child(ctx, results)].ty = ctx.specializations[id].result; }
    ctx.specializations[id].state = 2;
    return id;
}
// A checked file that declares no main in any namespace is a library: its
// declarations are checked without an entry point, as `goose check` does.
fn check_program(ctx: Compiler&, library: bool) {
    initialization_order(ctx, 0);
    for n in ctx.global_order { check_binding(ctx, n, 0); }
    var main_symbol = -1;
    for s, i in ctx.symbols { if s.scope == 0 && s.kind == 3 && s.ns < 0 && ctx.tokens[s.token].text == "main" { main_symbol = i; } }
    var declares_main = false;
    for n in ctx.declarations { if ctx.nodes[n].tag == N_FUNCTION && ctx.tokens[ctx.nodes[n].token].file == 0 && ctx.tokens[ctx.nodes[n].token].text == "main" { declares_main = true; } }
    if main_symbol < 0 && !(library && !declares_main) { write_stderr("error: no root-file main function\n"); exit(1); }
    if main_symbol >= 0 { check_function(ctx, main_symbol, -1, 0); }
    // Fully annotated, non-generic top-level bodies are checked even unused.
    // Generic and nested declarations remain demand-driven.
    let original_symbols = ctx.symbols.len;
    for i in original_symbols {
        let s = ctx.symbols[i];
        if s.scope != 0 { continue; }
        if s.kind == 1 {
            let d = ctx.nodes[s.decl];
            if d.tag == N_ALIAS { resolve_type(ctx, d.a, 0); }
            else if d.tag == N_STRUCT && ctx.nodes[d.a].first < 0 { struct_type(ctx, s.decl, 0); }
        }
        if s.kind == 3 && ctx.nodes[s.decl].first < 0 && ctx.nodes[s.decl].flags & 2 == 0 {
            var typed = true;
            var e = ctx.nodes[ctx.nodes[s.decl].a].first;
            while e >= 0 { if ctx.nodes[ctx.edges[e].value].a < 0 { typed = false; } e = ctx.edges[e].next; }
            if typed { check_function(ctx, i, -1, 0); }
        }
    }
    // Replay after bodies have closed, including recursive back edges whose
    // eventual shrink effects were not known on the first traversal.
    var changed = true;
    while changed {
        let before = ctx.effect_revision;
        for call in ctx.checked_calls {
            ctx.checking_function = ctx.scopes[call.scope].function;
            var effect = ctx.specializations[call.callee].shrinks;
            while effect >= 0 {
                let shrink = ctx.shrinks[ctx.edges[effect].value];
                if !shrink.balanced && !ctx.nodes[call.node].standalone { error_at(ctx, ctx.nodes[call.node].token, "not implemented yet: call that shrinks within a larger expression"); }
                check_shrink(ctx, shrink.root, shrink.element, call.scope, ctx.nodes[call.node].token, shrink.balanced, true);
                effect = ctx.edges[effect].next;
            }
        }
        changed = ctx.effect_revision != before;
    }
    ctx.checking_function = -1;
    call_cycles(ctx);
    for call in ctx.checked_calls {
        let caller = ctx.scopes[call.scope].function;
        if caller >= 0 && ctx.specializations[call.callee].cycle == ctx.specializations[caller].cycle {
            for local in ctx.symbols {
                if local.kind == 2 && local.ty >= 0 && ctx.scopes[local.scope].function == caller && ctx.types[local.ty].size_class > 0 && scope_contains(ctx, local.scope, call.scope) { error_at(ctx, ctx.nodes[call.node].token, "call into a recursive cycle while nonfixed local is in scope"); }
            }
        }
    }
}
recursive fn stable_array_path(ctx: Compiler&, n: i64) -> bool {
    let x = ctx.nodes[n];
    if x.tag == N_NAME { let s = ctx.symbols[x.symbol]; return ctx.types[s.ty].kind != T_REFERENCE || s.flags & 1 == 0; }
    if x.tag == N_MEMBER { return ctx.types[x.ty].kind != T_REFERENCE && stable_array_path(ctx, x.a); }
    return false;
}
// A call is into a recursive cycle exactly when callee and caller share a
// strongly connected component of the call graph. The graph is laid out once
// as offsets and targets (calls grouped by caller), then one Tarjan pass
// stores each specialization's component on it.
fn call_cycles(ctx: Compiler&) {
    let count = ctx.specializations.len;
    ctx.call_start.push(0);
    for i in count { ctx.call_start.push(0); }
    for call in ctx.checked_calls { let f = ctx.scopes[call.scope].function; if f >= 0 { ctx.call_start[f + 1]++; } }
    for i in count { ctx.call_start[i + 1] += ctx.call_start[i]; }
    var fill: i64[>..] = [];
    for i in count { fill.push(ctx.call_start[i]); }
    for call in ctx.checked_calls { ctx.call_targets.push(-1); }
    for call in ctx.checked_calls {
        let f = ctx.scopes[call.scope].function;
        if f >= 0 { ctx.call_targets[fill[f]] = call.callee; fill[f]++; }
    }
    for i in count { if ctx.specializations[i].cycle_index < 0 { strong_connect(ctx, i); } }
}
recursive fn strong_connect(ctx: Compiler&, v: i64) {
    ctx.specializations[v].cycle_index = ctx.cycle_counter; ctx.specializations[v].cycle_low = ctx.cycle_counter; ctx.cycle_counter++;
    // The stack only grows (a pop would make check_program shrink ctx, §5.1).
    if ctx.cycle_top == ctx.cycle_stack.len { ctx.cycle_stack.push(v); } else { ctx.cycle_stack[ctx.cycle_top] = v; }
    ctx.cycle_top++; ctx.specializations[v].cycle_open = true;
    for e in ctx.call_start[v]..ctx.call_start[v + 1] {
        let w = ctx.call_targets[e];
        if ctx.specializations[w].cycle_index < 0 {
            strong_connect(ctx, w);
            if ctx.specializations[w].cycle_low < ctx.specializations[v].cycle_low { ctx.specializations[v].cycle_low = ctx.specializations[w].cycle_low; }
        } else if ctx.specializations[w].cycle_open && ctx.specializations[w].cycle_index < ctx.specializations[v].cycle_low {
            ctx.specializations[v].cycle_low = ctx.specializations[w].cycle_index;
        }
    }
    if ctx.specializations[v].cycle_low == ctx.specializations[v].cycle_index {
        var done = false;
        while !done {
            ctx.cycle_top--; let w = ctx.cycle_stack[ctx.cycle_top];
            ctx.specializations[w].cycle_open = false; ctx.specializations[w].cycle = v;
            done = w == v;
        }
    }
}
recursive fn initialization_order(ctx: Compiler&, file: i64) {
    if ctx.sources[file].visited != 0 { return; }
    ctx.sources[file].visited = 1;
    for n in ctx.declarations {
        if ctx.tokens[ctx.nodes[n].token].file == file && ctx.nodes[n].tag == N_IMPORT { initialization_order(ctx, ctx.nodes[n].a); }
    }
    for n in ctx.declarations {
        if ctx.tokens[ctx.nodes[n].token].file == file && ctx.nodes[n].tag == N_BIND { ctx.global_order.push(n); }
    }
    ctx.sources[file].visited = 2;
}

// Canonical semantic types and lexical symbols. Syntax type expressions stay
// immutable; nominal declarations are resolved lazily with cycle detection.
const T_VOID = 0;
const T_INTEGER = 1;
const T_FLOAT = 2;
const T_BOOL = 3;
const T_STRUCT = 4;
const T_ARRAY = 5;
const T_SLICE = 6;
const T_REFERENCE = 7;
const T_VARINT = 8;
const T_BOTTOM = 9;
// An enum's first lists its variant types. A variant type is a T_STRUCT whose
// element is its enum and whose count is its index (its tag).
const T_ENUM = 10;
const T_NULL = 11;

struct Type {
    kind: i64,
    element: i64 = -1,
    count: i64 = 0,
    flags: i64 = 0,
    decl: i64 = -1,
    bytes: i64 = 0,
    size_class: i64 = 0,
    first: i64 = -1,
    state: i64 = 0,
    template: i64 = -1,
    arguments: i64 = -1,
    scope: i64 = 0,
    view_visit: i64 = 0,
    // The user format overload's specialization that renders this type: -2
    // undecided, -1 none (structural rendering).
    formatter: i64 = -2,
    // An enum usable in fixed mode: every payload is fixed-size.
    fixed_ok: bool = true,
}
struct Field {
    token: i64,
    ty: i64,
    initializer: i64,
    flags: i64,
    offset: i64,
}
struct Scope { parent: i64, function: i64, depth: i64 }
struct Symbol {
    token: i64,
    ns: i64,
    kind: i64,
    decl: i64,
    scope: i64,
    ty: i64 = -1,
    state: i64 = 0,
    flags: i64 = 0,
    root: i64 = -1,
    known: bool = false,
    bits: u64 = 0,
    held: i64 = -1,
    fields: i64 = -1,
    length_root: i64 = -1,
    readonly: bool = false,
    growshrink: bool = false,
    inexact: bool = false,
    capture_limit: i64 = -1,
}


fn same_name(ctx: Compiler&, a: i64, b: i64) -> bool {
    if a < 0 || b < 0 { return a == b; }
    return ctx.tokens[a].text == ctx.tokens[b].text;
}
fn intern_type(ctx: Compiler&, t: Type) -> i64 {
    for existing, i in ctx.types {
        if existing.kind == t.kind && existing.element == t.element && existing.count == t.count && existing.flags == t.flags && existing.decl == t.decl { return i; }
    }
    let id = ctx.types.len; ctx.types.push(t); return id;
}
fn integer_type(ctx: Compiler&, bytes: i64, unsigned: bool) -> i64 {
    var flags = 0; if unsigned { flags = 2; }
    return intern_type(ctx, Type { kind: T_INTEGER, count: bytes, flags: flags, bytes: bytes });
}
fn slice_type(ctx: Compiler&, element: i64, readonly: bool) -> i64 {
    var flags = 0; if readonly { flags = 1; }
    return intern_type(ctx, Type { kind: T_SLICE, element: element, flags: flags, bytes: 16 });
}
fn reference_type(ctx: Compiler&, element: i64, readonly: bool) -> i64 {
    var flags = 0; if readonly { flags = 1; }
    var bytes = 8; if ctx.types[element].size_class == 2 { bytes = 16; }
    return intern_type(ctx, Type { kind: T_REFERENCE, element: element, flags: flags, bytes: bytes });
}
// An optional is a reference whose null is address 0 (flags bit 4).
fn optional_type(ctx: Compiler&, element: i64, readonly: bool) -> i64 {
    var flags = 4; if readonly { flags = 5; }
    var bytes = 8; if ctx.types[element].size_class == 2 { bytes = 16; }
    return intern_type(ctx, Type { kind: T_REFERENCE, element: element, flags: flags, bytes: bytes });
}
fn is_relative(ctx: Compiler&, ty: i64) -> bool { return ty >= 0 && ctx.types[ty].kind == T_REFERENCE && ctx.types[ty].flags & 24 != 0; }
// The reference a relative slot loads as and stores from.
fn plain_reference(ctx: Compiler&, ty: i64) -> i64 {
    if !is_relative(ctx, ty) { return ty; }
    let t = ctx.types[ty];
    if t.flags & 4 != 0 { return optional_type(ctx, t.element, t.flags & 1 != 0); }
    return reference_type(ctx, t.element, t.flags & 1 != 0);
}
fn is_optional(ctx: Compiler&, ty: i64) -> bool { return ty >= 0 && ctx.types[ty].kind == T_REFERENCE && ctx.types[ty].flags & 4 != 0; }
fn array_type(ctx: Compiler&, element: i64, mode: i64, count: i64) -> i64 {
    var size_class = 0;
    var bytes = ctx.types[element].bytes * count;
    if mode == 1 || (mode == 2 && count < 0) { size_class = 1; bytes = -1; }
    if mode >= 3 { size_class = 2; bytes = -1; }
    if mode == 2 && count >= 0 {
        var prefix = 1;
        if count > 255 { prefix = 2; }
        if count > 65535 { prefix = 4; }
        if count > 4294967295 { prefix = 8; }
        bytes += prefix;
    }
    if (mode == 0 || mode == 2 || mode == 4) && ctx.types[element].size_class != 0 { return -1; }
    if ctx.types[element].size_class == 2 { return -1; }
    return intern_type(ctx, Type { kind: T_ARRAY, element: element, count: count, flags: mode, bytes: bytes, size_class: size_class });
}
fn builtin_type(ctx: Compiler&, name: const u8[:]) -> i64 {
    if name == "i8" { return integer_type(ctx, 1, false); }
    if name == "i16" { return integer_type(ctx, 2, false); }
    if name == "i32" { return integer_type(ctx, 4, false); }
    if name == "i64" { return integer_type(ctx, 8, false); }
    if name == "u8" { return integer_type(ctx, 1, true); }
    if name == "u16" { return integer_type(ctx, 2, true); }
    if name == "u32" { return integer_type(ctx, 4, true); }
    if name == "u64" { return integer_type(ctx, 8, true); }
    if name == "f32" { return intern_type(ctx, Type { kind: T_FLOAT, count: 4, bytes: 4 }); }
    if name == "f64" { return intern_type(ctx, Type { kind: T_FLOAT, count: 8, bytes: 8 }); }
    if name == "bool" { return intern_type(ctx, Type { kind: T_BOOL, bytes: 1 }); }
    if name == "varint" { return intern_type(ctx, Type { kind: T_VARINT, bytes: -1, size_class: 1 }); }
    return -1;
}
fn scope_new(ctx: Compiler&, parent: i64, function: i64) -> i64 {
    let id = ctx.scopes.len;
    var depth = 0; if parent >= 0 { depth = ctx.scopes[parent].depth + 1; }
    ctx.scopes.push(Scope { parent: parent, function: function, depth: depth });
    return id;
}
// Symbols are found through a hash of (scope, name) chained through
// symbol_chain, newest first, so a lookup touches only its own bucket.
fn symbol_hash(ctx: Compiler&, scope: i64, token: i64) -> i64 {
    var h: u64 = 14695981039346656037 ^ (scope as u64);
    if token >= 0 { for c in ctx.tokens[token].text { h = (h ^ c) * 1099511628211; } }
    return ((h ^ (h >> 29)) & (ctx.symbol_buckets.len as u64 - 1)) as i64;
}
fn index_symbol(ctx: Compiler&, id: i64) {
    ctx.symbol_chain.push(-1);
    if ctx.symbols.len * 2 > ctx.symbol_buckets.len {
        var size = ctx.symbol_buckets.len * 2; if size < 1024 { size = 1024; }
        // Grow only: shrinking ctx's arrays here would make every caller of
        // register_symbol a possible shrink of ctx (§5.1).
        while ctx.symbol_buckets.len < size { ctx.symbol_buckets.push(-1); }
        for i in size { ctx.symbol_buckets[i] = -1; }
        for s, i in ctx.symbols {
            let b = symbol_hash(ctx, s.scope, s.token);
            ctx.symbol_chain[i] = ctx.symbol_buckets[b]; ctx.symbol_buckets[b] = i;
        }
        return;
    }
    let b = symbol_hash(ctx, ctx.symbols[id].scope, ctx.symbols[id].token);
    ctx.symbol_chain[id] = ctx.symbol_buckets[b]; ctx.symbol_buckets[b] = id;
}
fn find_symbol(ctx: Compiler&, token: i64, ns: i64, scope: i64, kind: i64) -> i64 {
    if ctx.symbol_buckets.len == 0 { return -1; }
    var i = ctx.symbol_buckets[symbol_hash(ctx, scope, token)];
    while i >= 0 {
        let s = ctx.symbols[i];
        if s.scope == scope && (kind == 0 || s.kind == kind) && same_name(ctx, s.token, token) && (scope != 0 || same_name(ctx, s.ns, ns)) { return i; }
        i = ctx.symbol_chain[i];
    }
    return -1;
}
fn lookup(ctx: Compiler&, n: i64, scope: i64, kind: i64) -> i64 {
    if ctx.nodes[n].flags & 1 == 0 {
        var s = scope;
        var outside = false;
        while s > 0 {
            // A default names what its declaration sees, never the caller's
            // locals: the walk leaves the call site for the declaration.
            if s == ctx.default_floor && !outside {
                outside = true;
                if kind == 2 { default_names_parameter(ctx, n); }
                s = ctx.default_scope; continue;
            }
            let id = find_symbol(ctx, ctx.nodes[n].token, -1, s, kind);
            if id >= 0 && outside && (ctx.symbols[id].kind == 2 || ctx.symbols[id].kind == 3) && ctx.scopes[s].function >= 0 {
                // A local declared after a nested function is not around its
                // declaration, so the walk goes on past it toward the global.
                if ctx.symbols[id].kind == 3 || ctx.default_limit < 0 || id < ctx.default_limit {
                    error_at(ctx, ctx.nodes[n].token, str("the default of parameter ", ctx.tokens[ctx.nodes[ctx.default_param].token].text, " of ", ctx.tokens[ctx.nodes[ctx.default_decl].token].text, " names ", ctx.tokens[ctx.nodes[n].token].text, ", a local where ", ctx.tokens[ctx.nodes[ctx.default_decl].token].text, " is declared, which a default cannot"));
                }
            } else if id >= 0 {
                let owner = ctx.scopes[scope].function;
                var visible = true;
                if kind == 2 && owner >= 0 && ctx.scopes[ctx.symbols[id].scope].function != owner {
                    let limit = ctx.symbols[ctx.specializations[owner].symbol].capture_limit;
                    if limit >= 0 && id >= limit { visible = false; }
                }
                if visible { return id; }
            }
            s = ctx.scopes[s].parent;
        }
    }
    let id = find_symbol(ctx, ctx.nodes[n].token, ctx.nodes[n].ns, 0, kind);
    if id >= 0 { return id; }
    if ctx.nodes[n].flags & 1 == 0 && ctx.nodes[n].ns >= 0 { return find_symbol(ctx, ctx.nodes[n].token, -1, 0, kind); }
    return -1;
}
fn default_names_parameter(ctx: Compiler&, n: i64) {
    var e = ctx.nodes[ctx.nodes[ctx.default_decl].a].first;
    while e >= 0 {
        let p = ctx.edges[e].value;
        if same_name(ctx, ctx.nodes[p].token, ctx.nodes[n].token) {
            error_at(ctx, ctx.nodes[n].token, str("the default of parameter ", ctx.tokens[ctx.nodes[ctx.default_param].token].text, " of ", ctx.tokens[ctx.nodes[ctx.default_decl].token].text, " names parameter ", ctx.tokens[ctx.nodes[n].token].text, ", which a default cannot"));
        }
        e = ctx.edges[e].next;
    }
}
fn register_symbol(ctx: Compiler&, token: i64, ns: i64, kind: i64, decl: i64, scope: i64, flags: i64) -> i64 {
    let previous = find_symbol(ctx, token, ns, scope, kind);
    if previous >= 0 && !(kind == 3 && ctx.symbols[previous].kind == 3) { error_at(ctx, token, "name already declared in this scope"); }
    let id = ctx.symbols.len;
    ctx.symbols.push(Symbol { token: token, ns: ns, kind: kind, decl: decl, scope: scope, flags: flags });
    index_symbol(ctx, id);
    return id;
}
fn register_declarations(ctx: Compiler&) {
    scope_new(ctx, -1, -1);
    intern_type(ctx, Type { kind: T_VOID });
    for n in ctx.declarations {
        let tag = ctx.nodes[n].tag;
        if tag == N_STRUCT || tag == N_ENUM || tag == N_ALIAS { register_symbol(ctx, ctx.nodes[n].token, ctx.nodes[n].ns, 1, n, 0, 0); }
        if tag == N_FUNCTION {
            let t = ctx.nodes[n].token;
            if !(ctx.tokens[t].file != 0 && ctx.tokens[t].text == "main" && ctx.nodes[n].ns < 0) { register_symbol(ctx, t, ctx.nodes[n].ns, 3, n, 0, 0); }
        }
        if tag == N_BIND {
            var e = ctx.nodes[n].first;
            while e >= 0 {
                let name = ctx.edges[e].value;
                ctx.nodes[name].symbol = register_symbol(ctx, ctx.nodes[name].token, ctx.nodes[name].ns, 2, n, 0, ctx.nodes[n].flags);
                e = ctx.edges[e].next;
            }
        }
    }
}

recursive fn constant_integer(ctx: Compiler&, n: i64) -> u64 {
    let tag = ctx.nodes[n].tag;
    if tag == N_INT { return ctx.tokens[ctx.nodes[n].token].integer; }
    if tag == N_NAME {
        if ctx.const_scope > 0 {
            // A size names constants: a local or type parameter hides them (3.3).
            let what = if ctx.const_what == 1 { "capacity" } else if ctx.const_what == 2 { "fill count" } else { "size" };
            let name = ctx.tokens[ctx.nodes[n].token].text;
            let local = lookup(ctx, n, ctx.const_scope, 2);
            if local >= 0 && ctx.symbols[local].scope != 0 { error_at(ctx, ctx.nodes[n].token, str("array ", what, " ", name, " names a local variable, not a constant")); }
            let param = lookup(ctx, n, ctx.const_scope, 1);
            if param >= 0 && ctx.symbols[param].decl < 0 { error_at(ctx, ctx.nodes[n].token, str("array ", what, " ", name, " names a type parameter, not a constant")); }
        }
        let s = lookup(ctx, n, 0, 2);
        if s >= 0 && ctx.symbols[s].flags & 1 == 0 {
            if ctx.symbols[s].state == 3 { error_at(ctx, ctx.nodes[n].token, "cyclic constant initializer"); }
            ctx.symbols[s].state = 3;
            let values = ctx.nodes[ctx.symbols[s].decl].b;
            if values >= 0 && ctx.nodes[values].first >= 0 {
                let outer = ctx.const_scope; ctx.const_scope = 0;
                let result = constant_integer(ctx, ctx.edges[ctx.nodes[values].first].value);
                ctx.const_scope = outer;
                ctx.symbols[s].state = 0; return result;
            }
        }
    }
    if tag == N_UNARY {
        let v = constant_integer(ctx, ctx.nodes[n].a);
        let op = ctx.tokens[ctx.nodes[n].token].text;
        if op == "(" { return v; }
        if op == "-" { return 0 - v; }
        if op == "~" { return ~v; }
    }
    if tag == N_BINARY {
        let a = constant_integer(ctx, ctx.nodes[n].a); let b = constant_integer(ctx, ctx.nodes[n].b);
        let op = ctx.tokens[ctx.nodes[n].token].text;
        if op == "+" { return a + b; }
        if op == "-" { return a - b; }
        if op == "*" { return a * b; }
        if op == "/" || op == "%" {
            if b == 0 { error_at(ctx, ctx.nodes[n].token, "zero divisor in constant"); }
            if a == 9223372036854775808 && b == 18446744073709551615 { error_at(ctx, ctx.nodes[n].token, "constant division overflow"); }
            if op == "/" { return a / b; } return a % b;
        }
        if op == "<<" { return a << b; }
        if op == ">>" { return a >> b; }
        if op == "&" { return a & b; }
        if op == "|" { return a | b; }
        if op == "^" { return a ^ b; }
    }
    error_at(ctx, ctx.nodes[n].token, "expected integer constant expression");
    return 0;
}

recursive fn resolve_type(ctx: Compiler&, n: i64, scope: i64) -> i64 {
    return resolve_type_at(ctx, n, scope, false);
}
recursive fn resolve_type_at(ctx: Compiler&, n: i64, scope: i64, reference_target: bool) -> i64 {
    if n < 0 { return 0; }
    let syntax = ctx.nodes[n];
    var ty = -1;
    if syntax.tag == N_TYPE {
        if ctx.tokens[syntax.token].text == "fn" && syntax.b >= 0 && child_count(ctx, syntax.b) > 1 { error_at(ctx, syntax.token, "not implemented yet: function types with multiple results"); }
        ty = builtin_type(ctx, ctx.tokens[syntax.token].text);
        if ty < 0 {
            let s = lookup(ctx, n, scope, 1);
            if s < 0 { error_at(ctx, syntax.token, str("unknown type '", ctx.tokens[syntax.token].text, "'")); }
            if ctx.symbols[s].decl < 0 {
                if ctx.symbols[s].ty < 0 { error_at(ctx, syntax.token, "cannot infer type parameter"); }
                if syntax.first >= 0 { error_at(ctx, syntax.token, "a type parameter takes no type arguments"); }
                return ctx.symbols[s].ty;
            }
            let d = ctx.symbols[s].decl;
            if ctx.nodes[d].tag == N_ALIAS {
                if ctx.symbols[s].state == 1 { error_at(ctx, syntax.token, "cyclic type alias"); }
                if syntax.first >= 0 { error_at(ctx, syntax.token, "a type alias takes no type arguments"); }
                ctx.symbols[s].state = 1; ty = resolve_type_at(ctx, ctx.nodes[d].a, ctx.symbols[s].scope, reference_target); ctx.symbols[s].state = 2;
            } else { ty = instantiate_struct(ctx, d, syntax.first, scope, reference_target); }
        }
    } else if syntax.tag == N_TYPE_MEMBER {
        let owner = resolve_type_at(ctx, syntax.a, scope, reference_target);
        if ctx.types[owner].kind != T_ENUM { error_at(ctx, syntax.token, "variant type of non-ADT type"); }
        ty = find_variant(ctx, owner, syntax.token);
        if ty < 0 { error_at(ctx, syntax.token, str("enum ", ctx.tokens[ctx.nodes[ctx.types[owner].decl].token].text, " has no variant named ", ctx.tokens[syntax.token].text)); }
    } else if syntax.tag == N_TYPE_MODE {
        let base = resolve_type_at(ctx, syntax.a, scope, reference_target);
        if ctx.types[base].kind != T_ENUM || ctx.types[base].flags & 1 != 0 { error_at(ctx, syntax.token, "only an enum type has a variable mode (T..)"); }
        ty = varmode_type(ctx, base);
    } else if syntax.tag == N_TYPE_ARRAY {
        let element = resolve_type(ctx, syntax.a, scope);
        no_fieldless_element(ctx, element, syntax.token);
        var count = -1;
        // A frozen array's count records its stored length width in bytes;
        // 0 is a LEB128 varint length.
        if syntax.flags & 15 == 1 {
            count = 4;
            if syntax.b >= 0 {
                let width = ctx.tokens[ctx.nodes[syntax.b].token].text;
                if width == "u8" { count = 1; } else if width == "u16" { count = 2; } else if width == "u64" { count = 8; } else if width == "varint" { count = 0; }
            }
        } else if syntax.b >= 0 && ctx.nodes[syntax.b].tag != N_TYPE {
            let outer = ctx.const_scope; let outer_what = ctx.const_what;
            ctx.const_scope = scope; ctx.const_what = if syntax.flags & 15 == 2 { 1 } else { 0 };
            let value = constant_integer(ctx, syntax.b);
            ctx.const_scope = outer; ctx.const_what = outer_what;
            if value > 281474976710656 { error_at(ctx, syntax.token, "array size is negative or exceeds the 48-bit limit"); }
            count = value as i64;
        }
        if ctx.types[element].size_class == 3 { error_at(ctx, syntax.token, "nested root owners are not supported"); }
        ty = array_type(ctx, element, syntax.flags & 15, count);
        if ty < 0 { error_at(ctx, syntax.token, "array element size class is not permitted"); }
    } else if syntax.tag == N_TYPE_SLICE {
        ty = slice_type(ctx, resolve_type_at(ctx, syntax.a, scope, true), syntax.flags & 16 != 0);
        no_fieldless_element(ctx, ctx.types[ty].element, syntax.token);
    } else if syntax.tag == N_TYPE_REF || syntax.tag == N_TYPE_OPTIONAL {
        var element = resolve_type_at(ctx, syntax.a, scope, true);
        var readonly = syntax.flags & 16 != 0;
        if syntax.tag == N_TYPE_OPTIONAL && is_relative(ctx, element) {
            let r = ctx.types[element];
            ty = intern_type(ctx, Type { kind: T_REFERENCE, element: r.element, count: r.count, flags: r.flags | 4, decl: r.decl, bytes: r.bytes });
        } else if syntax.tag == N_TYPE_OPTIONAL {
            // T&? is T?: optional only makes a reference nullable.
            if ctx.types[element].kind == T_REFERENCE { readonly = readonly || ctx.types[element].flags & 1 != 0; element = ctx.types[element].element; }
            ty = optional_type(ctx, element, readonly);
        } else if syntax.b >= 0 {
            // T&<w> stores the link as a w-wide offset: from the slot itself
            // (signed), or from the base of a global pool array plus one.
            let width = ctx.tokens[ctx.nodes[syntax.b].token].text;
            var bytes = 0;
            if width == "u8" { bytes = 1; } else if width == "u16" { bytes = 2; } else if width == "u32" { bytes = 4; } else if width == "u64" { bytes = 8; }
            if bytes == 0 { error_at(ctx, ctx.nodes[syntax.b].token, "not implemented yet: varint relative references"); }
            var pool = -1; var field = -1; var flags = 8;
            if syntax.c >= 0 {
                flags = 16;
                var path = syntax.c;
                if ctx.nodes[path].tag == N_MEMBER { path = ctx.nodes[path].a; }
                pool = lookup(ctx, path, 0, 2);
                if pool < 0 || ctx.symbols[pool].scope != 0 { error_at(ctx, ctx.nodes[path].token, "a relative reference's pool must be a global array"); }
                if ctx.nodes[syntax.c].tag == N_MEMBER {
                    // The field is named by its first spelling's token, so
                    // the type is the same wherever it is written; the owner's
                    // type may still be unresolved here.
                    field = ctx.nodes[syntax.c].token;
                    for t in ctx.types { if t.kind == T_REFERENCE && t.flags & 16 != 0 && t.decl == pool && t.count >= 256 && same_name(ctx, t.count / 256 - 1, field) { field = t.count / 256 - 1; } }
                }
            }
            if readonly { flags |= 1; }
            ty = intern_type(ctx, Type { kind: T_REFERENCE, element: element, count: bytes + (field + 1) * 256, flags: flags, decl: pool, bytes: bytes });
        } else { ty = reference_type(ctx, element, readonly); }
    } else { error_at(ctx, syntax.token, "not implemented yet: this type form"); }
    ctx.nodes[n].ty = ty;
    return ty;
}
fn same_type_arguments(ctx: Compiler&, a: i64, b: i64) -> bool {
    var left = a; var right = b;
    while left >= 0 && right >= 0 {
        if ctx.edges[left].value != ctx.edges[right].value { return false; }
        left = ctx.edges[left].next; right = ctx.edges[right].next;
    }
    return left == right;
}
recursive fn instantiate_struct(ctx: Compiler&, decl: i64, written: i64, caller_scope: i64, reference_target: bool) -> i64 {
    var kind = T_STRUCT; if ctx.nodes[decl].tag == N_ENUM { kind = T_ENUM; }
    let what = if kind == T_ENUM { "enum" } else { "struct" };
    var param = ctx.nodes[ctx.nodes[decl].a].first;
    if param < 0 {
        if written >= 0 { error_at(ctx, ctx.nodes[decl].token, str("non-generic ", what, " takes no type arguments")); }
        let ty = intern_type(ctx, Type { kind: kind, decl: decl });
        if reference_target && ctx.types[ty].state == 1 { return ty; }
        return nominal_type(ctx, decl, 0);
    }
    var argument = written; var types = -1; var last = -1;
    while param >= 0 && argument >= 0 {
        if ctx.nodes[ctx.edges[param].value].a >= 0 { error_at(ctx, ctx.nodes[decl].token, "not implemented yet: constrained type parameters"); }
        let ty = resolve_type(ctx, ctx.edges[argument].value, caller_scope);
        let edge = ctx.edges.len; ctx.edges.push(Edge { value: ty });
        if last < 0 { types = edge; } else { ctx.edges[last].next = edge; } last = edge;
        param = ctx.edges[param].next; argument = ctx.edges[argument].next;
    }
    if param >= 0 || argument >= 0 { error_at(ctx, ctx.nodes[decl].token, str("generic ", what, " requires its type arguments")); }
    for t, i in ctx.types {
        if t.kind == kind && t.template == decl && same_type_arguments(ctx, t.arguments, types) {
            if t.state == 1 && !reference_target { error_at(ctx, ctx.nodes[decl].token, str(what, " contains itself by value")); }
            return i;
        }
    }
    let bindings = scope_new(ctx, 0, -1);
    param = ctx.nodes[ctx.nodes[decl].a].first; argument = types;
    while param >= 0 {
        let symbol = register_symbol(ctx, ctx.nodes[ctx.edges[param].value].token, -1, 1, -1, bindings, 0);
        ctx.symbols[symbol].ty = ctx.edges[argument].value; ctx.symbols[symbol].state = 2;
        param = ctx.edges[param].next; argument = ctx.edges[argument].next;
    }
    let specialized = clone_tree(ctx, decl);
    let ty = intern_type(ctx, Type { kind: kind, decl: specialized });
    ctx.types[ty].template = decl; ctx.types[ty].arguments = types; ctx.types[ty].scope = bindings;
    // A layout that needs a larger instance of itself would never finish.
    ctx.instantiation_depth++;
    if ctx.instantiation_depth > 16 { error_at(ctx, ctx.nodes[decl].token, str("would chain more than 16 instantiations of ", ctx.tokens[ctx.nodes[decl].token].text, ", each needed by the one before")); }
    let result = nominal_type(ctx, specialized, bindings);
    ctx.instantiation_depth--;
    return result;
}
recursive fn nominal_type(ctx: Compiler&, decl: i64, scope: i64) -> i64 {
    if ctx.nodes[decl].tag == N_ENUM { return enum_type(ctx, decl, scope); }
    return struct_type(ctx, decl, scope);
}
// Const on an owned value qualifies its contents. Its var binding can still
// be replaced as a whole. References and slices also carry type qualifiers.
recursive fn syntax_readonly(ctx: Compiler&, n: i64, scope: i64) -> bool {
    if n < 0 { return false; }
    let syntax = ctx.nodes[n];
    if syntax.flags & 16 != 0 { return true; }
    if syntax.tag == N_TYPE && builtin_type(ctx, ctx.tokens[syntax.token].text) < 0 {
        let s = lookup(ctx, n, scope, 1);
        if s >= 0 && ctx.symbols[s].decl >= 0 && ctx.nodes[ctx.symbols[s].decl].tag == N_ALIAS { return syntax_readonly(ctx, ctx.nodes[ctx.symbols[s].decl].a, scope); }
    }
    return false;
}
recursive fn struct_type(ctx: Compiler&, decl: i64, scope: i64) -> i64 {
    let id = intern_type(ctx, Type { kind: T_STRUCT, decl: decl });
    if ctx.types[id].state == 2 { return id; }
    if ctx.types[id].state == 1 { error_at(ctx, ctx.nodes[decl].token, "struct contains itself by value"); }
    layout_fields(ctx, id, decl, scope);
    return id;
}
// An enum is a tag (u8, or u16 past 256 variants) and room for its largest
// payload. Each variant is a struct-like type of its own, laid out first.
recursive fn enum_type(ctx: Compiler&, decl: i64, scope: i64) -> i64 {
    let id = intern_type(ctx, Type { kind: T_ENUM, decl: decl });
    if ctx.types[id].state == 2 { return id; }
    if ctx.types[id].state == 1 { error_at(ctx, ctx.nodes[decl].token, "enum contains itself by value"); }
    ctx.types[id].state = 1;
    var payload = 0; var count = 0; var last = -1;
    var e = ctx.nodes[decl].first;
    while e >= 0 {
        let v = ctx.edges[e].value;
        let vt = intern_type(ctx, Type { kind: T_STRUCT, element: id, count: count, decl: v });
        ctx.types[vt].scope = ctx.types[id].scope;
        layout_fields(ctx, vt, v, scope);
        if ctx.types[vt].size_class == 2 { error_at(ctx, ctx.nodes[v].token, "not implemented yet: resizable variant payloads"); }
        if ctx.types[vt].size_class == 1 { ctx.types[id].fixed_ok = false; }
        if ctx.types[vt].first >= 0 && ctx.types[vt].bytes > payload { payload = ctx.types[vt].bytes; }
        let edge = ctx.edges.len; ctx.edges.push(Edge { value: vt });
        if last < 0 { ctx.types[id].first = edge; } else { ctx.edges[last].next = edge; }
        last = edge; count++;
        e = ctx.edges[e].next;
    }
    var tag = 1; if count > 256 { tag = 2; }
    ctx.types[id].bytes = tag + payload; ctx.types[id].state = 2;
    for t, i in ctx.types { if t.kind == T_ENUM && t.flags & 1 != 0 && t.element == id { ctx.types[i].first = ctx.types[id].first; } }
    return id;
}
// Variable mode (E..) gives each value exactly its variant's bytes: a tag,
// then the payload packed. It shares its variants with the fixed type E,
// its element; one named while E is still being laid out (through a
// reference in a payload) gets them when E is finished.
fn varmode_type(ctx: Compiler&, base: i64) -> i64 {
    let id = intern_type(ctx, Type { kind: T_ENUM, element: base, flags: 1, decl: ctx.types[base].decl });
    if ctx.types[id].state == 0 {
        ctx.types[id].state = 2; ctx.types[id].size_class = 1; ctx.types[id].bytes = -1;
        ctx.types[id].first = ctx.types[base].first; ctx.types[id].scope = ctx.types[base].scope;
        ctx.types[id].template = ctx.types[base].template; ctx.types[id].arguments = ctx.types[base].arguments;
    }
    return id;
}
fn enum_base(ctx: Compiler&, ty: i64) -> i64 {
    if ctx.types[ty].kind == T_ENUM && ctx.types[ty].flags & 1 != 0 { return ctx.types[ty].element; }
    return ty;
}
// A variant or an enum in its other mode constructs a new value of the enum.
fn adapts_enum(ctx: Compiler&, from: i64, to: i64) -> bool {
    if from == to || ctx.types[to].kind != T_ENUM { return false; }
    let f = ctx.types[from];
    if f.kind == T_STRUCT && f.element >= 0 { return f.element == enum_base(ctx, to); }
    return f.kind == T_ENUM && enum_base(ctx, from) == enum_base(ctx, to) && (ctx.types[to].flags & 1 != 0 || ctx.types[to].fixed_ok);
}
// The count is not stored on the type: it is part of the interning key.
fn enum_tag_bytes(ctx: Compiler&, ty: i64) -> i64 {
    var count = 0; var e = ctx.types[ty].first;
    while e >= 0 { count++; e = ctx.edges[e].next; }
    if count > 256 { return 2; }
    return 1;
}
fn find_variant(ctx: Compiler&, ty: i64, token: i64) -> i64 {
    var e = ctx.types[ty].first;
    while e >= 0 { let vt = ctx.edges[e].value; if same_name(ctx, ctx.nodes[ctx.types[vt].decl].token, token) { return vt; } e = ctx.edges[e].next; }
    return -1;
}
fn is_variant(ctx: Compiler&, ty: i64) -> bool { ctx.types[ty].kind == T_STRUCT && ctx.types[ty].element >= 0 }
fn has_payload(ctx: Compiler&, ty: i64) -> bool { ctx.nodes[ctx.types[ty].decl].flags & 1 != 0 }
// A variant type with no fields is a value of its own, but never a field or
// an element: it would take no bytes (§3.4).
// Nor is a zero-length array (or limited array of capacity 0).
fn zero_size(ctx: Compiler&, ty: i64) -> const u8[:] {
    let t = ctx.types[ty];
    if t.state == 1 { return ""; }
    if is_variant(ctx, ty) && t.first < 0 { return "a variant type with no fields"; }
    if t.kind == T_ARRAY && (t.flags == 0 || t.flags == 2) && t.count == 0 { return "a zero-length array"; }
    return "";
}
fn no_fieldless_element(ctx: Compiler&, ty: i64, token: i64) {
    let what = zero_size(ctx, ty);
    if what.len == 0 { return; }
    var text: u8[>..] = []; format(text, "an element cannot be ", what, ": "); type_text(ctx, ty, text);
    error_at(ctx, token, text);
}
fn no_zero_size_field(ctx: Compiler&, owner: i64, ty: i64, token: i64) {
    let what = zero_size(ctx, ty);
    if what.len == 0 { return; }
    var text: u8[>..] = [];
    format(text, "field ", ctx.tokens[token].text, " of ", if is_variant(ctx, owner) { "variant " } else { "struct " }); type_text(ctx, owner, text);
    format(text, " cannot be ", what, ": "); type_text(ctx, ty, text);
    error_at(ctx, token, text);
}
// Bytes behind the tag in variable mode: an empty payload `V {}` takes none.
fn stored_payload(ctx: Compiler&, ty: i64) -> bool { ctx.types[ty].first >= 0 }
recursive fn layout_fields(ctx: Compiler&, id: i64, decl: i64, scope: i64) {
    ctx.types[id].state = 1;
    var offset = 0;
    var size_class = 0;
    // A root struct (size class 3) owns each field's storage separately.
    let root = ctx.nodes[decl].tag == N_STRUCT && ctx.nodes[decl].flags & 64 != 0;
    var e = ctx.nodes[decl].first;
    var last = -1;
    while e >= 0 {
        let n = ctx.edges[e].value;
        if ctx.nodes[n].tag == N_PAD { error_at(ctx, ctx.nodes[n].token, "not implemented yet: explicit padding"); }
        let ft = resolve_type(ctx, ctx.nodes[n].a, scope);
        // A root owner is a local or global declaration only (spec 3.4).
        if ctx.types[ft].size_class == 3 { error_at(ctx, ctx.nodes[n].token, "nested root owners are not supported"); }
        no_zero_size_field(ctx, id, ft, ctx.nodes[n].token);
        if is_relative(ctx, ft) { plain_reference(ctx, ft); }
        if size_class == 2 && !root { error_at(ctx, ctx.nodes[n].token, "resizable field must be the final field"); }
        if ctx.types[ft].size_class > size_class { size_class = ctx.types[ft].size_class; }
        let f = ctx.fielddefs.len;
        ctx.fielddefs.push(Field { token: ctx.nodes[n].token, ty: ft, initializer: ctx.nodes[n].b, flags: ctx.nodes[n].flags, offset: offset });
        let edge = ctx.edges.len; ctx.edges.push(Edge { value: f });
        if last < 0 { ctx.types[id].first = edge; } else { ctx.edges[last].next = edge; }
        last = edge;
        offset += ctx.types[ft].bytes;
        e = ctx.edges[e].next;
    }
    if offset == 0 { offset = 1; }
    if root { size_class = 3; }
    if size_class > 0 { offset = -1; }
    ctx.types[id].bytes = offset; ctx.types[id].size_class = size_class; ctx.types[id].state = 2;
}
// A type as Goose spells it, for diagnostics.
recursive fn type_text(ctx: Compiler&, ty: i64, out: u8[>..]&) {
    if ty < 0 { out.append("?"); return; }
    let t = ctx.types[ty];
    if t.kind == T_VOID { out.append("void"); }
    else if t.kind == T_BOTTOM { out.append("never"); }
    else if t.kind == T_BOOL { out.append("bool"); }
    else if t.kind == T_VARINT { out.append("varint"); }
    else if t.kind == T_INTEGER { format(out, if t.flags & 2 != 0 { "u" } else { "i" }, t.bytes * 8); }
    else if t.kind == T_FLOAT { format(out, "f", t.bytes * 8); }
    else if t.kind == T_ENUM && t.flags & 1 != 0 { type_text(ctx, t.element, out); out.append(".."); }
    else if is_variant(ctx, ty) { format(out, ctx.tokens[ctx.nodes[ctx.types[t.element].decl].token].text, ".", ctx.tokens[ctx.nodes[t.decl].token].text); }
    else if t.kind == T_STRUCT || t.kind == T_ENUM {
        out.append(ctx.tokens[ctx.nodes[t.decl].token].text);
        if t.arguments >= 0 {
            out.push('<'); var e = t.arguments; var comma = false;
            while e >= 0 { if comma { out.append(", "); } comma = true; type_text(ctx, ctx.edges[e].value, out); e = ctx.edges[e].next; }
            out.push('>');
        }
    } else if t.kind == T_SLICE { if t.flags & 1 != 0 { out.append("const "); } type_text(ctx, t.element, out); out.append("[:]"); }
    else if t.kind == T_REFERENCE {
        if t.flags & 1 != 0 { out.append("const "); }
        type_text(ctx, t.element, out);
        if t.flags & 4 != 0 && t.flags & 24 == 0 { out.push('?'); }
        else {
            out.push('&');
            if t.flags & 24 != 0 {
                out.push('<'); out.push('u'); format(out, t.bytes * 8);
                if t.flags & 16 != 0 { out.append(" in "); out.append(ctx.tokens[ctx.symbols[t.decl].token].text); if t.count >= 256 { out.push('.'); out.append(ctx.tokens[t.count / 256 - 1].text); } }
                out.push('>');
                if t.flags & 4 != 0 { out.push('?'); }
            }
        }
    }
    else if t.kind == T_ARRAY {
        type_text(ctx, t.element, out);
        if t.flags == 0 { format(out, "[", t.count, "]"); }
        else if t.flags == 1 { out.append("[]"); }
        else if t.flags == 2 { if t.count >= 0 { format(out, "[..", t.count, "]"); } else { out.append("[..]"); } }
        else if t.flags == 3 { out.append("[>..]"); }
        else { out.append("[>..<]"); }
    } else { format(out, "type#", ty); }
}
fn find_field(ctx: Compiler&, ty: i64, token: i64) -> i64 {
    var e = ctx.types[ty].first;
    while e >= 0 { let f = ctx.edges[e].value; if same_name(ctx, ctx.fielddefs[f].token, token) { return f; } e = ctx.edges[e].next; }
    return -1;
}
fn element_type(ctx: Compiler&, ty: i64) -> i64 {
    if ctx.types[ty].kind == T_REFERENCE { return element_type_plain(ctx, ctx.types[ty].element); }
    return element_type_plain(ctx, ty);
}
fn element_type_plain(ctx: Compiler&, ty: i64) -> i64 {
    if ctx.types[ty].kind == T_ARRAY || ctx.types[ty].kind == T_SLICE { return ctx.types[ty].element; }
    return -1;
}

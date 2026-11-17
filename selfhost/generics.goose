// Generic function signatures are resolved before body specialization. The
// generated function's lexical scope contains concrete type bindings; clones
// are cached by the template and type arguments, without changing the template.
recursive fn unresolved_type(ctx: Compiler&, n: i64, scope: i64) -> bool {
    if n < 0 { return false; }
    let x = ctx.nodes[n];
    if x.tag == N_TYPE && builtin_type(ctx, ctx.tokens[x.token].text) < 0 {
        let s = lookup(ctx, n, scope, 1);
        if s >= 0 && ctx.symbols[s].decl < 0 && ctx.symbols[s].ty < 0 { return true; }
    }
    if unresolved_type(ctx, x.a, scope) || unresolved_type(ctx, x.b, scope) { return true; }
    var e = x.first;
    while e >= 0 { if unresolved_type(ctx, ctx.edges[e].value, scope) { return true; } e = ctx.edges[e].next; }
    return false;
}

fn natural_argument_type(ctx: Compiler&, value: Value) -> i64 {
    if value.place >= 0 && ctx.types[value.ty].size_class > 0 { return reference_type(ctx, value.ty, value.readonly); }
    return value.ty;
}

recursive fn infer_type_pattern(ctx: Compiler&, pattern: i64, actual: i64, scope: i64) {
    let p = ctx.nodes[pattern];
    if p.tag == N_TYPE {
        let s = lookup(ctx, pattern, scope, 1);
        if s >= 0 && ctx.symbols[s].decl < 0 {
            if ctx.symbols[s].ty < 0 { ctx.symbols[s].ty = actual; }
            return;
        }
        var ty = actual;
        if ctx.types[ty].kind == T_REFERENCE { ty = ctx.types[ty].element; }
        if s >= 0 && ctx.types[ty].kind == T_STRUCT && ctx.types[ty].template == ctx.symbols[s].decl {
            var pe = p.first; var ae = ctx.types[ty].arguments;
            while pe >= 0 && ae >= 0 {
                infer_type_pattern(ctx, ctx.edges[pe].value, ctx.edges[ae].value, scope);
                pe = ctx.edges[pe].next; ae = ctx.edges[ae].next;
            }
        }
        return;
    }
    if p.tag == N_TYPE_REF {
        var ty = actual;
        if ctx.types[ty].kind == T_REFERENCE { ty = ctx.types[ty].element; }
        infer_type_pattern(ctx, p.a, ty, scope); return;
    }
    if p.tag == N_TYPE_ARRAY || p.tag == N_TYPE_SLICE {
        let element = element_type(ctx, actual);
        if element >= 0 { infer_type_pattern(ctx, p.a, element, scope); }
    }
}

recursive fn specialize_signature(ctx: Compiler&, symbol: i64, call: i64, caller_scope: i64, probing: bool) -> i64 {
    let original = ctx.symbols[symbol]; let decl = ctx.nodes[original.decl];
    var generic = decl.first >= 0;
    var p = ctx.nodes[decl.a].first;
    while p >= 0 { if ctx.nodes[ctx.edges[p].value].a < 0 { generic = true; } p = ctx.edges[p].next; }
    let written = ctx.nodes[ctx.nodes[call].a].first;
    if generic && decl.flags & 2 != 0 { error_at(ctx, decl.token, "extern functions must be fully typed and non-generic"); }
    if !generic {
        if written >= 0 { if probing { return -1; } error_at(ctx, ctx.nodes[call].token, "non-generic function takes no type arguments"); }
        return symbol;
    }
    if !arity_fits(ctx, original.decl, child_count(ctx, call)) { if probing { return -1; } error_at(ctx, ctx.nodes[call].token, "argument count mismatch"); }
    let bindings = scope_new(ctx, original.scope, ctx.scopes[original.scope].function);
    var key = -1; var last = -1;
    var g = decl.first; var supplied = written;
    while g >= 0 {
        let parameter = ctx.nodes[ctx.edges[g].value];
        if parameter.a >= 0 { if probing { return -1; } error_at(ctx, parameter.token, "not implemented yet: constrained function type parameters"); }
        let s = register_symbol(ctx, parameter.token, -1, 1, -1, bindings, 0);
        if supplied >= 0 { ctx.symbols[s].ty = resolve_type(ctx, ctx.edges[supplied].value, caller_scope); supplied = ctx.edges[supplied].next; }
        let edge = ctx.edges.len; ctx.edges.push(Edge { value: s });
        if last < 0 { key = edge; } else { ctx.edges[last].next = edge; } last = edge;
        g = ctx.edges[g].next;
    }
    if supplied >= 0 { if probing { return -1; } error_at(ctx, ctx.nodes[call].token, "too many type arguments"); }
    let specialized = clone_tree(ctx, original.decl);
    ctx.nodes[specialized].first = -1; ctx.nodes[specialized].last = -1;
    p = ctx.nodes[ctx.nodes[specialized].a].first;
    while p >= 0 {
        let param = ctx.edges[p].value;
        if ctx.nodes[param].a < 0 {
            let s = register_symbol(ctx, ctx.nodes[param].token, -1, 1, -1, bindings, 0);
            let edge = ctx.edges.len; ctx.edges.push(Edge { value: s });
            if last < 0 { key = edge; } else { ctx.edges[last].next = edge; } last = edge;
            let pattern = node(ctx, N_TYPE, ctx.nodes[param].token); ctx.nodes[param].a = pattern;
        }
        p = ctx.edges[p].next;
    }
    // Read each argument once. Explicitly supplied type arguments can give
    // empty array literals and branch expressions their destination type.
    // Parameters left to their defaults have no argument here: a default
    // decides no type variable, and check_function checks it later.
    p = ctx.nodes[ctx.nodes[specialized].a].first; var a = ctx.nodes[call].first;
    while p >= 0 && a >= 0 {
        let param = ctx.nodes[ctx.edges[p].value]; let arg = ctx.edges[a].value;
        var expected = -1;
        if !unresolved_type(ctx, param.a, bindings) { expected = resolve_type(ctx, param.a, bindings); }
        if ctx.nodes[call].flags & 512 == 0 && !(a == ctx.nodes[call].first && ctx.nodes[call].flags & 256 != 0) { check_expression(ctx, arg, caller_scope, expected); }
        p = ctx.edges[p].next; a = ctx.edges[a].next;
    }
    ctx.nodes[call].flags |= 512;
    // Nonliteral values constrain a shared type before adaptable literals do.
    for pass in 2 {
        p = ctx.nodes[ctx.nodes[specialized].a].first; a = ctx.nodes[call].first;
        while p >= 0 && a >= 0 {
            let value = value_of(ctx, ctx.edges[a].value);
            if (pass == 1) == value.known { infer_type_pattern(ctx, ctx.nodes[ctx.edges[p].value].a, natural_argument_type(ctx, value), bindings); }
            p = ctx.edges[p].next; a = ctx.edges[a].next;
        }
    }
    var e = key;
    while e >= 0 {
        let s = ctx.edges[e].value;
        if ctx.symbols[s].ty < 0 { if probing { return -1; } error_at(ctx, ctx.nodes[call].token, str("cannot infer type parameter '", ctx.tokens[ctx.symbols[s].token].text, "'")); }
        ctx.edges[e].value = ctx.symbols[s].ty; e = ctx.edges[e].next;
    }
    for instance in ctx.function_instances {
        if instance.template == symbol && same_type_arguments(ctx, instance.arguments, key) { return instance.symbol; }
    }
    // Kind 5 is private: name lookup must keep finding the original template,
    // including recursive calls that instantiate another type combination.
    let concrete = register_symbol(ctx, original.token, original.ns, 5, specialized, bindings, original.flags);
    ctx.symbols[concrete].state = 2; ctx.symbols[concrete].capture_limit = original.capture_limit;
    ctx.function_instances.push(FunctionInstance { template: symbol, arguments: key, symbol: concrete });
    return concrete;
}

// A call may leave out trailing parameters that declare defaults (§7.1).
fn arity_fits(ctx: Compiler&, decl: i64, written: i64) -> bool {
    var count = 0; var e = ctx.nodes[ctx.nodes[decl].a].first;
    while e >= 0 {
        if count >= written && ctx.nodes[ctx.edges[e].value].b < 0 { return false; }
        count++; e = ctx.edges[e].next;
    }
    return count >= written;
}
fn overload_member(ctx: Compiler&, candidate: i64, selected: i64) -> bool {
    let a = ctx.symbols[candidate]; let b = ctx.symbols[selected];
    return a.kind == 3 && a.scope == b.scope && same_name(ctx, a.token, b.token) && (a.scope != 0 || same_name(ctx, a.ns, b.ns));
}
recursive fn resolve_overload(ctx: Compiler&, selected: i64, call: i64, scope: i64) -> i64 {
    // Overloads share the (scope, name) bucket of the selected symbol, so
    // only its chain is walked. The result (the unique lowest tier, or an
    // ambiguity) does not depend on the order candidates are seen in.
    let head = ctx.symbol_buckets[symbol_hash(ctx, ctx.symbols[selected].scope, ctx.symbols[selected].token)];
    var count = 0;
    var c = head;
    while c >= 0 { if overload_member(ctx, c, selected) { count++; } c = ctx.symbol_chain[c]; }
    if count == 1 { return specialize_signature(ctx, selected, call, scope, false); }
    var e = ctx.nodes[call].first;
    while e >= 0 {
        if ctx.nodes[call].flags & 512 == 0 && !(e == ctx.nodes[call].first && ctx.nodes[call].flags & 256 != 0) { check_expression(ctx, ctx.edges[e].value, scope, -1); }
        e = ctx.edges[e].next;
    }
    ctx.nodes[call].flags |= 512;
    var best = -1; var best_tier = 4; var ambiguous = false;
    var next = head;
    while next >= 0 {
        let i = next; next = ctx.symbol_chain[i];
        if !overload_member(ctx, i, selected) { continue; }
        if !arity_fits(ctx, ctx.symbols[i].decl, child_count(ctx, call)) { continue; }
        let concrete = specialize_signature(ctx, i, call, scope, true);
        if concrete < 0 { continue; }
        let decl = ctx.nodes[ctx.symbols[concrete].decl];
        var tier = 0; if concrete != i { tier = 1; }
        var matches = true;
        // A default is no argument: the written arguments alone rank.
        var p = ctx.nodes[decl.a].first; e = ctx.nodes[call].first;
        while p >= 0 && e >= 0 {
            let actual = value_of(ctx, ctx.edges[e].value);
            let declared = resolve_type(ctx, ctx.nodes[ctx.edges[p].value].a, ctx.symbols[concrete].scope);
            let expected = parameter_destination(ctx, declared, decl.flags & 2 != 0);
            if !fits(ctx, actual, expected) { matches = false; }
            else {
                let want = ctx.types[expected];
                let exact = actual.ty == expected || (want.kind == T_REFERENCE && decay(ctx, actual).ty == want.element && actual.place >= 0);
                // An integer converted to a float is the last resort (§7.1).
                if ctx.types[decay(ctx, actual).ty].kind == T_INTEGER && want.kind == T_FLOAT { tier = 3; }
                else if !exact && tier < 2 { tier = 2; }
            }
            p = ctx.edges[p].next; e = ctx.edges[e].next;
        }
        if matches {
            if tier < best_tier { best = concrete; best_tier = tier; ambiguous = false; }
            else if tier == best_tier { ambiguous = true; }
        }
    }
    if best < 0 && tag_dispatch(ctx, selected, call) { return -2; }
    if best < 0 { error_at(ctx, ctx.nodes[call].token, "no overload matches the arguments"); }
    if ambiguous { error_at(ctx, ctx.nodes[call].token, "ambiguous overload: several candidates have the same matching tier"); }
    return best;
}
// Case functions (§8.2): when no overload takes an enum argument as it is,
// the call dispatches on its tag where every variant has exactly one
// non-generic overload taking that variant type in the argument's place,
// the other arguments fitting as for any call. The call's b is the place
// and its c the overloads in variant order (specializations once checked).
fn case_overload(ctx: Compiler&, selected: i64, call: i64, place: i64, vt: i64, varmode: bool) -> i64 {
    var found = -1;
    var c = ctx.symbol_buckets[symbol_hash(ctx, ctx.symbols[selected].scope, ctx.symbols[selected].token)];
    while c >= 0 {
        let decl = ctx.nodes[ctx.symbols[c].decl];
        if overload_member(ctx, c, selected) && decl.first < 0 && child_count(ctx, decl.a) == child_count(ctx, call) {
            var applies = true; var p = ctx.nodes[decl.a].first; var e = ctx.nodes[call].first; var i = 0;
            while p >= 0 && applies {
                let syntax = ctx.nodes[ctx.edges[p].value].a;
                if syntax < 0 { applies = false; }
                else {
                    let declared = resolve_type(ctx, syntax, ctx.symbols[c].scope);
                    // A variable-mode payload may also be taken by reference.
                    if i == place { applies = declared == vt || (varmode && ctx.types[declared].kind == T_REFERENCE && ctx.types[declared].element == vt); }
                    else { applies = fits(ctx, value_of(ctx, ctx.edges[e].value), parameter_destination(ctx, declared, decl.flags & 2 != 0)); }
                }
                p = ctx.edges[p].next; e = ctx.edges[e].next; i++;
            }
            if applies { if found >= 0 { return -1; } found = c; }
        }
        c = ctx.symbol_chain[c];
    }
    return found;
}
fn tag_dispatch(ctx: Compiler&, selected: i64, call: i64) -> bool {
    var place = 0; var e = ctx.nodes[call].first;
    while e >= 0 {
        let arg = decay(ctx, value_of(ctx, ctx.edges[e].value));
        if ctx.types[arg.ty].kind == T_ENUM {
            var cases = -1; var last = -1; var complete = true;
            var v = ctx.types[arg.ty].first;
            while v >= 0 && complete {
                let found = case_overload(ctx, selected, call, place, ctx.edges[v].value, ctx.types[arg.ty].flags & 1 != 0);
                if found < 0 { complete = false; }
                else {
                    let edge = ctx.edges.len; ctx.edges.push(Edge { value: found });
                    if last < 0 { cases = edge; } else { ctx.edges[last].next = edge; } last = edge;
                }
                v = ctx.edges[v].next;
            }
            if complete { ctx.nodes[call].b = place; ctx.nodes[call].c = cases; return true; }
        }
        place++; e = ctx.edges[e].next;
    }
    return false;
}

// C expressions are lowered to temporaries, preserving Goose's left-to-right
// evaluation. Newly generated snippets are owned by the text arena; existing
// views and static literals are borrowed without copying.
fn emit(ctx: Compiler&, s: const u8[:]) { ctx.c_output.append(s); }
fn save_text(ctx: Compiler&, s: const u8[:]) -> const u8[:] { return own_text(ctx, s); }
fn c_type(ctx: Compiler&, ty: i64) -> const u8[:] {
    let t = ctx.types[ty];
    if t.kind == T_VOID || t.kind == T_BOTTOM { return "void"; }
    if t.kind == T_BOOL { return "uint8_t"; }
    if t.kind == T_INTEGER {
        if t.flags & 2 != 0 { return save_text(ctx, str("uint", t.bytes * 8, "_t")); }
        return save_text(ctx, str("int", t.bytes * 8, "_t"));
    }
    if t.kind == T_FLOAT { if t.bytes == 4 { return "float"; } return "double"; }
    if t.kind == T_SLICE { return "gg_slice"; }
    if t.kind == T_ARRAY && t.flags >= 3 { return "gg_header"; }
    if t.kind == T_REFERENCE && ctx.types[t.element].size_class == 2 { return "gg_reference"; }
    // A variable-size value, and a reference to one, is the address of its
    // packed bytes on a data stack.
    if t.size_class == 1 || (t.kind == T_REFERENCE && ctx.types[t.element].size_class == 1) { return "uint8_t *"; }
    return save_text(ctx, str("gg_type_", ty));
}
// Locals and parameters are numbered within their owning function, so two
// specializations of one declaration spell their bodies identically.
fn c_name(ctx: Compiler&, symbol: i64) -> const u8[:] {
    if ctx.local_names[symbol] >= 0 { return save_text(ctx, str("v", ctx.local_names[symbol])); }
    return save_text(ctx, str("v", symbol));
}
// A reference to a specialization's function or frame is written as a marker
// (byte 1, the id, byte 2), resolved to its class representative on output.
fn emit_ref(ctx: Compiler&, prefix: const u8[:], spec: i64) {
    emit(ctx, prefix); ctx.c_output.push(1); emit(ctx, str(spec)); ctx.c_output.push(2);
}
fn declare_ref(ctx: Compiler&, prefix: const u8[:], spec: i64) {
    ctx.c_declarations.append(prefix); ctx.c_declarations.push(1); format(ctx.c_declarations, spec); ctx.c_declarations.push(2);
}
// A multiple-result call's record is named by its order in the function,
// not by its node, which differs between specializations.
fn c_multi(ctx: Compiler&, call: i64) -> const u8[:] {
    var i = 0;
    while i < ctx.c_multis.len { if ctx.c_multis[i] == call { return save_text(ctx, str("gg_multi_", i / 2)); } i += 2; }
    abort("internal error: multiple-result call not emitted");
}
fn c_frame(ctx: Compiler&, target: i64) -> const u8[:] {
    if target == ctx.c_function { return "(&frame)"; }
    var out: u8[>..] = [];
    out.append("frame.parent");
    var current = ctx.scopes[ctx.symbols[ctx.specializations[ctx.c_function].symbol].scope].function;
    while current != target {
        if current < 0 { abort("internal error: missing lexical frame"); }
        out.append("->parent");
        current = ctx.scopes[ctx.symbols[ctx.specializations[current].symbol].scope].function;
    }
    return save_text(ctx, out);
}
// A global initializer runs in main before any function frame exists, so the
// locals of its blocks, and of the defaults its calls take, are kept beside
// the globals rather than in a frame.
fn global_storage(ctx: Compiler&, symbol: i64) -> bool {
    let scope = ctx.symbols[symbol].scope;
    return scope == 0 || ctx.scopes[scope].function < 0;
}
fn c_symbol(ctx: Compiler&, symbol: i64) -> const u8[:] {
    if global_storage(ctx, symbol) { return save_text(ctx, str("gg_globals.", c_name(ctx, symbol))); }
    let owner = ctx.scopes[ctx.symbols[symbol].scope].function;
    if ctx.return_locals[owner] == symbol { return save_text(ctx, str("(*", c_frame(ctx, owner), "->result.header)")); }
    return save_text(ctx, str(c_frame(ctx, ctx.scopes[ctx.symbols[symbol].scope].function), "->", c_name(ctx, symbol)));
}
fn c_stack(ctx: Compiler&, symbol: i64) -> const u8[:] {
    if global_storage(ctx, symbol) { return save_text(ctx, str("gg_get_stack(", ctx.symbol_slots[symbol], ")")); }
    let owner = ctx.scopes[ctx.symbols[symbol].scope].function;
    if ctx.return_locals[owner] == symbol { return save_text(ctx, str(c_frame(ctx, owner), "->result.stack")); }
    return save_text(ctx, str("gg_get_stack(", c_frame(ctx, ctx.scopes[ctx.symbols[symbol].scope].function), "->base + ", ctx.symbol_slots[symbol], ")"));
}
fn temporary(ctx: Compiler&, ty: i64) -> const u8[:] {
    let id = ctx.c_temporary; ctx.c_temporary++;
    let name = save_text(ctx, str("t", id));
    format(ctx.c_declarations, "  ", c_type(ctx, ty), " ", name, ";\n");
    return name;
}
fn raw_temporary(ctx: Compiler&, type_name: const u8[:]) -> const u8[:] {
    let id = ctx.c_temporary; ctx.c_temporary++;
    let name = save_text(ctx, str("t", id));
    format(ctx.c_declarations, "  ", type_name, " ", name, ";\n");
    return name;
}
fn snapshot(ctx: Compiler&, v: CValue) -> CValue {
    if ctx.types[v.ty].kind == T_VOID || ctx.types[v.ty].kind == T_BOTTOM { return v; }
    let name = temporary(ctx, v.ty); emit(ctx, str("  ", name, " = ", v.code, ";\n"));
    if ctx.types[v.ty].size_class == 1 { return CValue { code: name, ty: v.ty, address: name, stack: v.stack }; }
    return CValue { code: name, ty: v.ty, address: save_text(ctx, str("&", name)), stack: v.stack };
}
fn c_decay(ctx: Compiler&, v: CValue) -> CValue {
    if ctx.types[v.ty].kind != T_REFERENCE { return v; }
    let ty = ctx.types[v.ty].element;
    if ctx.types[ty].size_class == 2 { return CValue { code: save_text(ctx, str("(*(", v.code, ").header)")), ty: ty, address: save_text(ctx, str("(", v.code, ").header")), stack: save_text(ctx, str("(", v.code, ").stack")) }; }
    if ctx.types[ty].size_class == 1 { return CValue { code: v.code, ty: ty, address: v.code, stack: "" }; }
    return CValue { code: save_text(ctx, str("(*(", v.code, "))")), ty: ty, address: v.code, stack: "" };
}
fn c_view(ctx: Compiler&, v: CValue) -> const u8[:] {
    let a = c_decay(ctx, v); let t = ctx.types[a.ty];
    if t.kind == T_SLICE { return a.code; }
    if t.kind != T_ARRAY { abort("internal error: array view expected"); }
    if t.flags == 0 { return save_text(ctx, str("gg_view((", a.code, ").data, ", t.count, ")")); }
    if t.flags == 2 && t.count >= 0 { return save_text(ctx, str("gg_view((", a.code, ").e, (", a.code, ").len)")); }
    if t.flags == 2 { return save_text(ctx, str("gg_dyn_view(", a.code, ")")); }
    if t.flags == 1 { return save_text(ctx, str("gg_frozen_view(", a.code, ", ", t.count, ")")); }
    if t.flags >= 3 { return save_text(ctx, str("gg_view((", a.code, ").base, (", a.code, ").len)")); }
    abort("unsupported C array view");
}
fn c_reference(ctx: Compiler&, v: CValue) -> const u8[:] {
    if ctx.types[v.ty].kind == T_REFERENCE { return v.code; }
    if ctx.types[v.ty].size_class == 2 { return save_text(ctx, str("gg_ref(", v.address, ", ", v.stack, ")")); }
    return v.address;
}
fn c_adapt(ctx: Compiler&, v: CValue, target: i64) -> const u8[:] {
    if ctx.types[target].kind == T_REFERENCE { return c_reference(ctx, v); }
    let a = c_decay(ctx, v);
    if ctx.types[target].kind == T_SLICE { return c_view(ctx, a); }
    if ctx.types[target].kind == T_ENUM && ctx.types[target].flags & 1 == 0 && is_variant(ctx, a.ty) { return save_text(ctx, str("gg_wrap_", a.ty, "(", a.code, ")")); }
    if ctx.types[target].kind == T_ENUM && ctx.types[target].flags & 1 == 0 && ctx.types[a.ty].kind == T_ENUM && a.ty != target { return save_text(ctx, str("gg_fix_", a.ty, "(", a.code, ")")); }
    if numeric(ctx, target) { return save_text(ctx, str("((", c_type(ctx, target), ")(", a.code, "))")); }
    if limited_fixed(ctx, target) && a.ty != target { return save_text(ctx, str("gg_limit_", target, "(", c_view(ctx, a), ")")); }
    return a.code;
}
fn c_literal(ctx: Compiler&, s: const u8[:]) -> const u8[:] {
    var result: u8[>..] = [];
    result.push('"');
    for c in s {
        // Three octal digits cannot consume following hexadecimal digits.
        result.push('\\'); result.push('0' + (c >> 6));
        result.push('0' + ((c >> 3) & 7)); result.push('0' + (c & 7));
    }
    result.push('"'); return save_text(ctx, result);
}
fn c_array_temp(ctx: Compiler&, ty: i64) -> CValue {
    let name = temporary(ctx, ty); let slot = ctx.c_slots; ctx.c_slots++;
    let stack = save_text(ctx, str("gg_get_stack(frame.base + ", slot, ")"));
    emit(ctx, str("  ", name, ".base = ", stack, "->base + ", stack, "->top; ", name, ".len = 0;\n"));
    return CValue { code: name, ty: ty, address: save_text(ctx, str("&", name)), stack: stack };
}
// A variable-size temporary is built at the bottom of a slot of its own.
fn c_variable_temp(ctx: Compiler&, ty: i64) -> CValue {
    let name = temporary(ctx, ty); let slot = ctx.c_slots; ctx.c_slots++;
    let stack = save_text(ctx, str("gg_get_stack(frame.base + ", slot, ")"));
    emit(ctx, str("  ", stack, "->top = 0; ", name, " = ", stack, "->base;\n"));
    return CValue { code: name, ty: ty, address: name, stack: stack };
}
fn limited_fixed(ctx: Compiler&, ty: i64) -> bool { return ctx.types[ty].kind == T_ARRAY && ctx.types[ty].flags == 2 && ctx.types[ty].count >= 0; }
fn limited_width(count: i64) -> i64 {
    if count > 4294967295 { return 8; }
    if count > 65535 { return 4; }
    if count > 255 { return 2; }
    return 1;
}
fn field_index(ctx: Compiler&, ty: i64, f: i64) -> i64 {
    var e = ctx.types[ty].first; var i = 0;
    while e >= 0 { if ctx.edges[e].value == f { return i; } i++; e = ctx.edges[e].next; }
    return -1;
}
fn field_count(ctx: Compiler&, ty: i64) -> i64 {
    var e = ctx.types[ty].first; var i = 0;
    while e >= 0 { i++; e = ctx.edges[e].next; }
    return i;
}
// A field of a fixed struct is a C member; a field of a variable-size struct
// is found by walking the packed fields before it.
fn c_field(ctx: Compiler&, ty: i64, base: const u8[:], f: i64) -> CValue {
    let ft = ctx.fielddefs[f].ty;
    if ctx.types[ty].size_class == 0 {
        let field = save_text(ctx, str("(", base, ").f", f));
        return CValue { code: field, ty: ft, address: save_text(ctx, str("&(", field, ")")), stack: "" };
    }
    let at = save_text(ctx, str("gg_at_", ty, "(", base, ", ", field_index(ctx, ty, f), ")"));
    if ctx.types[ft].size_class == 1 { return CValue { code: at, ty: ft, address: at, stack: "" }; }
    let pointer = save_text(ctx, str("((", c_type(ctx, ft), " *)", at, ")"));
    return CValue { code: save_text(ctx, str("(*", pointer, ")")), ty: ft, address: pointer, stack: "" };
}
// The stored length, capacity and data of a limited array lvalue.
struct LimitedParts { length: const u8[:], width: i64, cap: const u8[:], data: const u8[:] }
fn limited_parts(ctx: Compiler&, a: CValue) -> LimitedParts {
    let t = ctx.types[a.ty];
    if t.count >= 0 { return LimitedParts { length: save_text(ctx, str("&(", a.code, ").len")), width: limited_width(t.count), cap: save_text(ctx, str(t.count)), data: save_text(ctx, str("(", a.code, ").e")) }; }
    return LimitedParts { length: save_text(ctx, str("((", a.code, ") + 4)")), width: 4, cap: save_text(ctx, str("((int64_t)*(uint32_t *)(", a.code, "))")), data: save_text(ctx, str("((", a.code, ") + 8)")) };
}
fn c_element_size(ctx: Compiler&, ty: i64) -> const u8[:] { return save_text(ctx, str("sizeof(", c_type(ctx, ty), ")")); }

recursive fn emit_type(ctx: Compiler&, ty: i64) {
    if ctx.c_type_state[ty] == 2 { return; }
    let t = ctx.types[ty];
    if ctx.c_type_state[ty] == 1 { return; }
    ctx.c_type_state[ty] = 1;
    if t.kind == T_STRUCT && t.size_class == 1 {
        var e = t.first;
        while e >= 0 { emit_type(ctx, ctx.fielddefs[ctx.edges[e].value].ty); e = ctx.edges[e].next; }
    } else if t.kind == T_STRUCT {
        emit(ctx, str("typedef struct gg_type_", ty, " gg_type_", ty, ";\n"));
        var e = t.first;
        while e >= 0 { emit_type(ctx, ctx.fielddefs[ctx.edges[e].value].ty); e = ctx.edges[e].next; }
        if t.size_class != 0 { error_at(ctx, ctx.nodes[t.decl].token, "not implemented yet: resizable struct C layout"); }
        emit(ctx, str("#pragma pack(push, 1)\nstruct gg_type_", ty, " {\n"));
        e = t.first;
        if e < 0 { emit(ctx, "unsigned char empty;\n"); }
        while e >= 0 { let f = ctx.edges[e].value; emit(ctx, str("  ", c_type(ctx, ctx.fielddefs[f].ty), " f", f, ";\n")); e = ctx.edges[e].next; }
        emit(ctx, "};\n#pragma pack(pop)\n");
    } else if t.kind == T_ENUM && (t.flags & 1 != 0 || !t.fixed_ok) {
        // Variable mode is packed bytes; a fixed mode its payloads rule out has no C type.
        var e = t.first;
        while e >= 0 { emit_type(ctx, ctx.edges[e].value); e = ctx.edges[e].next; }
    } else if t.kind == T_ENUM {
        // A tag and a union of the payloads; payload-less variants take no room.
        emit(ctx, str("typedef struct gg_type_", ty, " gg_type_", ty, ";\n"));
        var e = t.first; var payloads = false;
        while e >= 0 { emit_type(ctx, ctx.edges[e].value); if has_payload(ctx, ctx.edges[e].value) { payloads = true; } e = ctx.edges[e].next; }
        emit(ctx, str("#pragma pack(push, 1)\nstruct gg_type_", ty, " {\n  ", if enum_tag_bytes(ctx, ty) == 2 { "uint16_t" } else { "uint8_t" }, " tag;\n"));
        if payloads {
            emit(ctx, "  union {\n"); e = t.first;
            while e >= 0 { let vt = ctx.edges[e].value; if has_payload(ctx, vt) { emit(ctx, str("    ", c_type(ctx, vt), " v", ctx.types[vt].count, ";\n")); } e = ctx.edges[e].next; }
            emit(ctx, "  } u;\n");
        }
        emit(ctx, "};\n#pragma pack(pop)\n");
    } else if t.kind == T_ARRAY && t.flags == 0 {
        emit_type(ctx, t.element);
        var extent = t.count; if extent == 0 { extent = 1; }
        emit(ctx, str("#pragma pack(push, 1)\ntypedef struct { ", c_type(ctx, t.element), " data[", extent, "]; } ", c_type(ctx, ty), ";\n#pragma pack(pop)\n"));
    } else if limited_fixed(ctx, ty) {
        emit_type(ctx, t.element);
        var extent = t.count; if extent == 0 { extent = 1; }
        emit(ctx, str("#pragma pack(push, 1)\ntypedef struct { uint", limited_width(t.count) * 8, "_t len; ", c_type(ctx, t.element), " e[", extent, "]; } ", c_type(ctx, ty), ";\n#pragma pack(pop)\n"));
    } else if t.kind == T_REFERENCE && ctx.types[t.element].size_class == 0 {
        emit_type(ctx, t.element); emit(ctx, str("typedef ", c_type(ctx, t.element), " *", c_type(ctx, ty), ";\n"));
    } else if t.kind == T_REFERENCE || t.kind == T_ARRAY || t.kind == T_SLICE { emit_type(ctx, t.element); }
    ctx.c_type_state[ty] = 2;
}

fn c_binary(ctx: Compiler&, op: const u8[:], a: CValue, b: CValue, result: i64) -> const u8[:] {
    let t = ctx.types[a.ty];
    if op == "==" || op == "!=" {
        if element_type(ctx, a.ty) >= 0 { return save_text(ctx, str(if op == "!=" { "!" } else { "" }, "gg_equal_elements_", element_type(ctx, a.ty), "(", c_view(ctx, a), ", ", c_view(ctx, b), ")")); }
        if t.kind == T_STRUCT || t.kind == T_ENUM { return save_text(ctx, str(if op == "!=" { "!" } else { "" }, "gg_eq_", a.ty, "(", a.code, ",", b.code, ")")); }
    }
    if t.kind == T_INTEGER {
        if op == "/" || op == "%" {
            let name = if t.flags & 2 != 0 { if op == "/" { "gg_udiv" } else { "gg_umod" } } else { if op == "/" { "gg_div" } else { "gg_mod" } };
            return save_text(ctx, str("((", c_type(ctx, result), ")", name, "(", a.code, ", ", b.code, "))"));
        }
        if op == "+" || op == "-" || op == "*" || op == "<<" {
            if op == "<<" { return save_text(ctx, str("((", c_type(ctx, result), ")((uint64_t)(", a.code, ") << ((uint64_t)(", b.code, ") & ", t.bytes * 8 - 1, ")))")); }
            return save_text(ctx, str("((", c_type(ctx, result), ")((uint64_t)(", a.code, ") ", op, " (uint64_t)(", b.code, ")))"));
        }
        if op == ">>" { return save_text(ctx, str("((", a.code, ") >> ((uint64_t)(", b.code, ") & ", t.bytes * 8 - 1, "))")); }
    }
    if t.kind == T_FLOAT && op == "%" { return save_text(ctx, str("fmod(", a.code, ", ", b.code, ")")); }
    return save_text(ctx, str("((", a.code, ") ", op, " (", b.code, "))"));
}

fn no_c_value(ctx: Compiler&) -> CValue { return CValue { code: "", ty: 0, address: "", stack: "" }; }
fn symbol_value(ctx: Compiler&, symbol: i64) -> CValue {
    let ty = ctx.symbols[symbol].ty; let name = c_symbol(ctx, symbol);
    var stack = -1; if ctx.types[ty].size_class == 2 { stack = symbol; }
    if ctx.types[ty].size_class == 1 {
        return CValue { code: name, ty: ty, address: name, stack: if ctx.symbol_slots[symbol] >= 0 { c_stack(ctx, symbol) } else { "" } };
    }
    return CValue { code: name, ty: ty, address: save_text(ctx, str("&(", name, ")")), stack: if stack >= 0 { c_stack(ctx, stack) } else { "" } };
}
fn converted(ctx: Compiler&, v: CValue, target: i64) -> CValue {
    return CValue { code: c_adapt(ctx, v, target), ty: target, address: v.address, stack: v.stack };
}
fn c_render(ctx: Compiler&, out: CValue, v: CValue) {
    let a = c_decay(ctx, v); let t = ctx.types[a.ty]; let dst = c_reference(ctx, out);
    if t.formatter >= 0 {
        // A rendered argument goes to its overload as a call would pass it.
        let params = ctx.specializations[t.formatter].parameters;
        let p = ctx.symbols[ctx.nodes[ctx.edges[ctx.edges[ctx.nodes[params].first].next].value].symbol].ty;
        let arg = snapshot(ctx, CValue { code: c_adapt(ctx, a, p), ty: p, address: "", stack: "" });
        emit_ref(ctx, "  gg_function_", t.formatter); emit(ctx, str("(", dst, ", ", arg.code, ", frame.base + ", ctx.c_slots, ");\n"));
    }
    else if (t.kind != T_INTEGER && t.kind != T_FLOAT && t.kind != T_BOOL && element_type(ctx, a.ty) != integer_type(ctx, 1, true)) {
        if ctx.formatters > 0 { emit(ctx, str("  gg_render_base = frame.base + ", ctx.c_slots, ";\n")); }
        emit(ctx, str("  gg_render_", a.ty, "(", dst, ",", a.code, ");\n"));
    }
    else if t.kind == T_INTEGER { emit(ctx, str("  ", if t.flags & 2 != 0 { "gg_unsigned" } else { "gg_integer" }, "(", dst, ", ", a.code, ");\n")); }
    else if t.kind == T_FLOAT { emit(ctx, str("  gg_float(", dst, ", ", a.code, ", ", if t.bytes == 4 { "1" } else { "0" }, ");\n")); }
    else if t.kind == T_BOOL { emit(ctx, str("  gg_bool(", dst, ", ", a.code, ");\n")); }
    else if element_type(ctx, a.ty) == integer_type(ctx, 1, true) { emit(ctx, str("  gg_text(", dst, ", ", c_view(ctx, a), ");\n")); }
}
fn c_result_field(ctx: Compiler&, code: const u8[:], ty: i64, index: i64) -> CValue {
    let field = save_text(ctx, str(code, ".r", index));
    return CValue { code: field, ty: ty, address: save_text(ctx, str("&(", field, ")")), stack: "" };
}
fn c_return_value(ctx: Compiler&, index: i64) -> CValue {
    var e = ctx.nodes[ctx.specializations[ctx.c_function].results].first;
    for i in index { e = ctx.edges[e].next; }
    return c_result_field(ctx, "gg_return", ctx.nodes[ctx.edges[e].value].ty, index);
}
recursive fn c_expression(ctx: Compiler&, n: i64) -> CValue {
    let x = ctx.nodes[n];
    let tag = x.tag;
    if tag == N_NAME { return symbol_value(ctx, x.symbol); }
    if tag == N_RESULT { return c_result_field(ctx, c_multi(ctx, x.a), x.ty, x.flags); }
    if tag == N_INT || tag == N_BOOL {
        return CValue { code: save_text(ctx, str("((", c_type(ctx, x.ty), ")UINT64_C(", x.bits, "))")), ty: x.ty, address: "", stack: "" };
    }
    // Keep the validated spelling and let the C library round it exactly.
    // This also handles overflow literals without an invalid C constant.
    if tag == N_FLOAT { return CValue { code: save_text(ctx, str("strtod(\"", ctx.tokens[x.token].text, "\", NULL)")), ty: x.ty, address: "", stack: "" }; }
    if tag == N_STRING { return CValue { code: save_text(ctx, str("gg_view((void *)", c_literal(ctx, ctx.tokens[x.token].text), ", ", ctx.tokens[x.token].text.len, ")")), ty: x.ty, address: "", stack: "" }; }
    if tag == N_UNARY {
        let a = c_expression(ctx, x.a); let op = ctx.tokens[x.token].text;
        if op == "&" { return CValue { code: c_reference(ctx, a), ty: x.ty, address: "", stack: a.stack }; }
        if op == "(" { return a; }
        let v = snapshot(ctx, c_decay(ctx, a));
        if op == "-" && ctx.types[v.ty].kind == T_INTEGER { return CValue { code: save_text(ctx, str("((", c_type(ctx, x.ty), ")((uint64_t)0 - (uint64_t)(", v.code, ")))")), ty: x.ty, address: "", stack: "" }; }
        return CValue { code: save_text(ctx, str("(", op, "(", v.code, "))")), ty: x.ty, address: "", stack: "" };
    }
    if tag == N_BINARY {
        let op = ctx.tokens[x.token].text;
        let a = snapshot(ctx, converted(ctx, c_expression(ctx, x.a), if ctx.nodes[x.a].target >= 0 { ctx.nodes[x.a].target } else { decay(ctx, value_of(ctx, x.a)).ty }));
        if op == "&&" || op == "||" {
            let result = temporary(ctx, x.ty); emit(ctx, str("  ", result, " = ", a.code, ";\n  if (", if op == "||" { "!" } else { "" }, result, ") {\n"));
            let b = c_decay(ctx, c_expression(ctx, x.b)); emit(ctx, str("  ", result, " = ", b.code, ";\n  }\n"));
            return CValue { code: result, ty: x.ty, address: save_text(ctx, str("&", result)), stack: "" };
        }
        let b = snapshot(ctx, converted(ctx, c_expression(ctx, x.b), if ctx.nodes[x.b].target >= 0 { ctx.nodes[x.b].target } else { decay(ctx, value_of(ctx, x.b)).ty }));
        return CValue { code: c_binary(ctx, op, a, b, x.ty), ty: x.ty, address: "", stack: "" };
    }
    if tag == N_CAST {
        let a = c_decay(ctx, c_expression(ctx, x.a));
        if ctx.types[a.ty].kind == T_FLOAT && ctx.types[x.ty].kind == T_INTEGER { return CValue { code: save_text(ctx, str("((", c_type(ctx, x.ty), ")gg_float_wrap((double)(", a.code, ")))")), ty: x.ty, address: "", stack: "" }; }
        return converted(ctx, a, x.ty);
    }
    if tag == N_MEMBER && x.flags & 1024 != 0 {
        let name = temporary(ctx, x.ty);
        emit(ctx, str("  memset(&", name, ", 0, sizeof(", name, ")); ", name, ".tag = ", ctx.types[x.symbol].count, ";\n"));
        return CValue { code: name, ty: x.ty, address: save_text(ctx, str("&", name)), stack: "" };
    }
    if tag == N_MEMBER {
        let a = c_decay(ctx, c_expression(ctx, x.a));
        if element_type(ctx, a.ty) >= 0 {
            if ctx.tokens[x.token].text == "cap" {
                let parts = limited_parts(ctx, a);
                return CValue { code: parts.cap, ty: x.ty, address: "", stack: "" };
            }
            return CValue { code: save_text(ctx, str("((int64_t)(", c_view(ctx, a), ").len)")), ty: x.ty, address: "", stack: "" };
        }
        let field = c_field(ctx, a.ty, a.code, x.symbol);
        if ctx.types[field.ty].kind == T_VARINT { return CValue { code: save_text(ctx, str("gg_zig_read(", field.code, ")")), ty: x.ty, address: "", stack: "" }; }
        return CValue { code: field.code, ty: x.ty, address: field.address, stack: "" };
    }
    if tag == N_INDEX || tag == N_SLICE {
        let a = c_expression(ctx, x.a);
        let view = raw_temporary(ctx, "gg_slice"); emit(ctx, str("  ", view, " = ", c_view(ctx, a), ";\n"));
        var lo = CValue { code: "0", ty: default_integer(ctx), address: "", stack: "" };
        if x.b >= 0 { lo = snapshot(ctx, c_decay(ctx, c_expression(ctx, x.b))); }
        let lower = if x.flags & 1 != 0 { save_text(ctx, str(view, ".len - ", lo.code)) } else { lo.code };
        let elem = element_type(ctx, a.ty);
        if tag == N_INDEX {
            let pointer = save_text(ctx, str("((", c_type(ctx, elem), " *)", view, ".data) + gg_index(", lower, ", ", view, ".len)"));
            let sampled = raw_temporary(ctx, save_text(ctx, str(c_type(ctx, elem), " *"))); emit(ctx, str("  ", sampled, " = ", pointer, ";\n"));
            return CValue { code: save_text(ctx, str("(*", sampled, ")")), ty: x.ty, address: sampled, stack: "" };
        }
        var hi = CValue { code: save_text(ctx, str(view, ".len")), ty: default_integer(ctx), address: "", stack: "" };
        if x.c >= 0 { hi = snapshot(ctx, c_decay(ctx, c_expression(ctx, x.c))); }
        let upper = if x.flags & 2 != 0 { save_text(ctx, str(view, ".len - ", hi.code)) } else { hi.code };
        return CValue { code: save_text(ctx, str("gg_sub(", view, ", ", lower, ", ", upper, ", sizeof(", c_type(ctx, elem), "))")), ty: x.ty, address: "", stack: "" };
    }
    if tag == N_CALL { return c_call(ctx, n, no_c_value(ctx)); }
    if tag == N_ARRAY || tag == N_FILL || tag == N_CONSTRUCT {
        if ctx.types[x.ty].size_class == 1 { let built = c_variable_temp(ctx, x.ty); c_into(ctx, n, built); return built; }
        let name = temporary(ctx, x.ty);
        let dest = CValue { code: name, ty: x.ty, address: save_text(ctx, str("&", name)), stack: "" };
        c_into(ctx, n, dest); return dest;
    }
    if tag == N_IF || tag == N_BLOCK || tag == N_MATCH || tag == N_LOOP || tag == N_EARLY {
        if x.ty == 0 || ctx.types[x.ty].kind == T_BOTTOM { c_into(ctx, n, no_c_value(ctx)); return no_c_value(ctx); }
        if ctx.types[x.ty].size_class == 1 { let dest = c_variable_temp(ctx, x.ty); c_into(ctx, n, dest); return dest; }
        if ctx.types[x.ty].size_class > 0 { let dest = c_array_temp(ctx, x.ty); c_into(ctx, n, dest); return dest; }
        let name = temporary(ctx, x.ty);
        let dest = CValue { code: name, ty: x.ty, address: save_text(ctx, str("&", name)), stack: "" };
        c_into(ctx, n, dest); return dest;
    }
    c_statement(ctx, n); return no_c_value(ctx);
}
recursive fn c_into(ctx: Compiler&, n: i64, dest: CValue) {
    let x = ctx.nodes[n];
    if x.tag == N_IF {
        let condition = snapshot(ctx, c_decay(ctx, c_expression(ctx, x.a))); emit(ctx, str("  if (", condition.code, ") {\n"));
        c_into(ctx, x.b, dest); emit(ctx, "  }");
        if x.c >= 0 { emit(ctx, " else {\n"); c_into(ctx, x.c, dest); emit(ctx, "  }"); }
        emit(ctx, "\n"); return;
    }
    if x.tag == N_MATCH { c_match(ctx, n, dest); return; }
    if x.tag == N_LOOP || x.tag == N_EARLY { c_loop(ctx, n, dest); return; }
    if x.tag == N_BLOCK {
        emit(ctx, "  {\n"); var e = x.first;
        while e >= 0 { c_statement(ctx, ctx.edges[e].value); e = ctx.edges[e].next; }
        if x.a >= 0 { c_into(ctx, x.a, dest); }
        emit(ctx, "  }\n"); return;
    }
    if x.tag == N_CALL && dest.ty != 0 && ctx.types[dest.ty].size_class == 1 && x.ty == dest.ty && x.symbol >= 0 { c_call(ctx, n, dest); return; }
    if dest.ty != 0 && ctx.types[dest.ty].size_class == 1 { c_build(ctx, n, dest); return; }
    if x.tag == N_CALL && ctx.types[x.ty].size_class == 2 && dest.ty != 0 { c_call(ctx, n, dest); return; }
    if x.tag == N_CONSTRUCT {
        // A variant built into its enum fills the payload in place, then the tag.
        let wrapped = dest.ty != 0 && ctx.types[dest.ty].kind == T_ENUM && is_variant(ctx, x.ty);
        var payload = save_text(ctx, str("(", dest.code, ")"));
        if wrapped { payload = save_text(ctx, str("(", dest.code, ").u.v", ctx.types[x.ty].count)); }
        var e = x.first;
        while e >= 0 {
            let init = ctx.edges[e].value; let f = ctx.nodes[init].symbol;
            var field = c_field(ctx, dest.ty, dest.code, f);
            if wrapped {
                let code = save_text(ctx, str(payload, ".f", f));
                field = CValue { code: code, ty: ctx.fielddefs[f].ty, address: save_text(ctx, str("&(", code, ")")), stack: "" };
            }
            c_into(ctx, ctx.nodes[init].a, CValue { code: field.code, ty: field.ty, address: field.address, stack: dest.stack });
            e = ctx.edges[e].next;
        }
        if wrapped { emit(ctx, str("  (", dest.code, ").tag = ", ctx.types[x.ty].count, ";\n")); }
        return;
    }
    if (x.tag == N_ARRAY || x.tag == N_FILL) && limited_fixed(ctx, dest.ty) {
        let elem = element_type(ctx, dest.ty);
        var count = ctx.types[x.ty].count; if x.tag == N_ARRAY { count = child_count(ctx, n); }
        if count > ctx.types[dest.ty].count { emit(ctx, "  gg_fail(\"limited array capacity exceeded\");\n"); return; }
        emit(ctx, str("  (", dest.code, ").len = ", count, ";\n"));
        if x.tag == N_FILL {
            let value = snapshot(ctx, converted(ctx, c_expression(ctx, x.a), elem)); let i = raw_temporary(ctx, "int64_t");
            emit(ctx, str("  for (", i, "=0; ", i, "<", count, "; ", i, "++) (", dest.code, ").e[", i, "] = ", value.code, ";\n"));
        } else {
            var e = x.first; var i = 0;
            while e >= 0 { let field = save_text(ctx, str("(", dest.code, ").e[", i, "]")); let address = save_text(ctx, str("&", field)); c_into(ctx, ctx.edges[e].value, CValue { code: field, ty: elem, address: address, stack: "" }); i++; e = ctx.edges[e].next; }
        }
        return;
    }
    if (x.tag == N_ARRAY || x.tag == N_FILL) && ctx.types[dest.ty].size_class == 2 && ctx.types[element_type(ctx, dest.ty)].size_class == 1 {
        // A sequential growable array: each element is built at its top.
        let elem = element_type(ctx, dest.ty); let decayed = c_decay(ctx, dest);
        var e = x.first;
        while e >= 0 { c_build(ctx, ctx.edges[e].value, CValue { code: "", ty: elem, address: "", stack: decayed.stack }); emit(ctx, str("  (", decayed.code, ").len++;\n")); e = ctx.edges[e].next; }
        return;
    }
    if x.tag == N_ARRAY || x.tag == N_FILL {
        let elem = element_type(ctx, dest.ty);
        if ctx.types[dest.ty].size_class == 2 {
            if x.tag == N_FILL {
                let value = snapshot(ctx, converted(ctx, c_expression(ctx, x.a), elem));
                let index = raw_temporary(ctx, "int64_t");
                emit(ctx, str("  for (", index, "=0; ", index, "<", ctx.types[x.ty].count, "; ", index, "++) gg_append(", c_reference(ctx, dest), ", &", value.code, ", 1, sizeof(", c_type(ctx, elem), "));\n"));
            } else {
                var e = x.first;
                while e >= 0 { let value = snapshot(ctx, converted(ctx, c_expression(ctx, ctx.edges[e].value), elem)); emit(ctx, str("  gg_append(", c_reference(ctx, dest), ", &", value.code, ", 1, sizeof(", c_type(ctx, elem), "));\n")); e = ctx.edges[e].next; }
            }
        } else {
            if x.tag == N_FILL {
                let value = snapshot(ctx, converted(ctx, c_expression(ctx, x.a), elem)); let i = raw_temporary(ctx, "int64_t");
                emit(ctx, str("  for (", i, "=0; ", i, "<", ctx.types[x.ty].count, "; ", i, "++) (", dest.code, ").data[", i, "] = ", value.code, ";\n"));
            } else {
                var e = x.first; var i = 0;
                while e >= 0 { let field = save_text(ctx, str("(", dest.code, ").data[", i, "]")); let address = save_text(ctx, str("&", field)); c_into(ctx, ctx.edges[e].value, CValue { code: field, ty: elem, address: address, stack: "" }); i++; e = ctx.edges[e].next; }
            }
        }
        return;
    }
    let v = c_expression(ctx, n);
    if dest.ty == 0 || v.ty == 0 || ctx.types[v.ty].kind == T_BOTTOM { if v.code.len > 0 { emit(ctx, str("  (void)(", v.code, ");\n")); } return; }
    if ctx.types[dest.ty].size_class == 2 {
        if ctx.c_function >= 0 && x.tag == N_NAME && x.symbol == ctx.return_locals[ctx.c_function] { return; }
        let elem = element_type(ctx, dest.ty);
        if ctx.types[elem].size_class == 1 {
            let view = raw_temporary(ctx, "gg_slice"); let decayed = c_decay(ctx, dest);
            emit(ctx, str("  ", view, " = ", c_view(ctx, v), ";\n  gg_push(", decayed.stack, ", ", view, ".data, (size_t)gg_span_", elem, "(", view, ".data, ", view, ".len)); (", decayed.code, ").len += ", view, ".len;\n"));
            return;
        }
        let view = c_view(ctx, v); emit(ctx, str("  gg_append(", c_reference(ctx, dest), ", (", view, ").data, (", view, ").len, sizeof(", c_type(ctx, elem), "));\n"));
    } else { emit(ctx, str("  ", dest.code, " = ", c_adapt(ctx, v, dest.ty), ";\n")); }
}
// Appends the value of n, as a value of the variable-size type dest.ty, at
// the top of dest.stack: built in place wherever the expression allows.
recursive fn c_build(ctx: Compiler&, n: i64, dest: CValue) {
    let x = ctx.nodes[n]; let t = ctx.types[dest.ty]; let stack = dest.stack;
    if x.tag == N_IF || x.tag == N_BLOCK || x.tag == N_MATCH || x.tag == N_LOOP || x.tag == N_EARLY { c_into(ctx, n, dest); return; }
    if x.tag == N_UNARY && ctx.tokens[x.token].text == "(" { c_build(ctx, x.a, dest); return; }
    if x.tag == N_CALL && x.ty == dest.ty && x.symbol >= 0 { c_into(ctx, n, dest); return; }
    if t.kind == T_ENUM { c_build_enum(ctx, n, dest); return; }
    if t.kind == T_VARINT {
        let v = snapshot(ctx, converted(ctx, c_expression(ctx, n), default_integer(ctx)));
        emit(ctx, str("  gg_push_zig(", stack, ", ", v.code, ");\n")); return;
    }
    if x.tag == N_CONSTRUCT && x.ty == dest.ty {
        var e = x.first;
        while e >= 0 { let init = ctx.edges[e].value; c_append_value(ctx, ctx.nodes[init].a, ctx.fielddefs[ctx.nodes[init].symbol].ty, stack); e = ctx.edges[e].next; }
        return;
    }
    if (x.tag == N_ARRAY || x.tag == N_FILL) && t.kind == T_ARRAY {
        var count = ctx.types[x.ty].count; if x.tag == N_ARRAY { count = child_count(ctx, n); }
        if t.flags == 1 { emit(ctx, str("  gg_push_len(", stack, ", ", count, ", ", t.count, ");\n")); }
        else { emit(ctx, str("  gg_push_len(", stack, ", ", count, ", 4); gg_push_len(", stack, ", ", count, ", 4);\n")); }
        if x.tag == N_FILL {
            let value = snapshot(ctx, converted(ctx, c_expression(ctx, x.a), t.element)); let i = raw_temporary(ctx, "int64_t");
            emit(ctx, str("  for (", i, "=0; ", i, "<", count, "; ", i, "++) gg_push(", stack, ", &", value.code, ", ", c_element_size(ctx, t.element), ");\n"));
        } else {
            var e = x.first;
            while e >= 0 { c_append_value(ctx, ctx.edges[e].value, t.element, stack); e = ctx.edges[e].next; }
        }
        return;
    }
    if x.tag == N_LIMITED {
        let cap = snapshot(ctx, converted(ctx, c_expression(ctx, x.a), default_integer(ctx)));
        emit(ctx, str("  gg_push_dyn(", stack, ", ", cap.code, ", ", c_element_size(ctx, t.element), ");\n")); return;
    }
    // A copy of an existing value, or a conversion from another array form.
    var source = n;
    if x.tag == N_CALL && x.symbol == -26 { source = first_child(ctx, n); }
    let v = c_decay(ctx, c_expression(ctx, source));
    if v.ty == dest.ty { emit(ctx, str("  gg_push(", stack, ", ", v.code, ", (size_t)gg_size_", dest.ty, "(", v.code, "));\n")); return; }
    if t.kind != T_ARRAY || element_type(ctx, v.ty) < 0 { abort("internal error: unsupported variable-size construction"); }
    let view = raw_temporary(ctx, "gg_slice"); emit(ctx, str("  ", view, " = ", c_view(ctx, v), ";\n"));
    let width = if t.flags == 1 { t.count } else { 4 };
    emit(ctx, str("  gg_push_len(", stack, ", ", view, ".len, ", width, ");\n"));
    if t.flags != 1 { emit(ctx, str("  gg_push_len(", stack, ", ", view, ".len, 4);\n")); }
    if ctx.types[t.element].size_class == 1 { emit(ctx, str("  gg_push(", stack, ", ", view, ".data, (size_t)gg_span_", t.element, "(", view, ".data, ", view, ".len));\n")); }
    else { emit(ctx, str("  gg_push(", stack, ", ", view, ".data, (size_t)", view, ".len * ", c_element_size(ctx, t.element), ");\n")); }
}
// Appends one field or element of type ty: a fixed value is staged in a C
// temporary, a variable one is built at the top.
recursive fn c_append_value(ctx: Compiler&, n: i64, ty: i64, stack: const u8[:]) {
    if ctx.types[ty].size_class == 1 { c_build(ctx, n, CValue { code: "", ty: ty, address: "", stack: stack }); return; }
    let name = temporary(ctx, ty);
    let address = save_text(ctx, str("&", name));
    c_into(ctx, n, CValue { code: name, ty: ty, address: address, stack: "" });
    emit(ctx, str("  gg_push(", stack, ", &", name, ", sizeof(", name, "));\n"));
}

// A fixed-mode enum is a C struct; a variable-mode one points at its tag
// byte, its payload packed right behind it.
fn c_tag(ctx: Compiler&, v: CValue) -> const u8[:] {
    if ctx.types[v.ty].flags & 1 != 0 { return save_text(ctx, str("(*(uint8_t *)(", v.code, "))")); }
    return save_text(ctx, str("(", v.code, ").tag"));
}
fn c_payload(ctx: Compiler&, v: CValue, vt: i64, by_reference: bool) -> const u8[:] {
    let k = ctx.types[vt].count;
    if ctx.types[v.ty].flags & 1 == 0 {
        if !has_payload(ctx, vt) { return save_text(ctx, str("(", c_type(ctx, vt), "){0}")); }
        return save_text(ctx, str("(", v.code, ").u.v", k));
    }
    if ctx.types[vt].size_class == 1 { return save_text(ctx, str("((uint8_t *)(", v.code, ") + 1)")); }
    if by_reference { return save_text(ctx, str("((", c_type(ctx, vt), " *)((uint8_t *)(", v.code, ") + 1))")); }
    if !stored_payload(ctx, vt) { return save_text(ctx, str("(", c_type(ctx, vt), "){0}")); }
    return save_text(ctx, str("(*(", c_type(ctx, vt), " *)((uint8_t *)(", v.code, ") + 1))"));
}
fn push_tag(ctx: Compiler&, stack: const u8[:], vt: i64) {
    emit(ctx, str("  gg_push(", stack, ", &(uint8_t){", ctx.types[vt].count, "}, 1);\n"));
}
// Builds a variable-mode enum at the top of dest's stack: from a variant
// literal or value, a payload-less constant, or the enum in either mode.
recursive fn c_build_enum(ctx: Compiler&, n: i64, dest: CValue) {
    let x = ctx.nodes[n]; let stack = dest.stack;
    if x.tag == N_CONSTRUCT && is_variant(ctx, x.ty) {
        push_tag(ctx, stack, x.ty);
        if stored_payload(ctx, x.ty) { c_append_value(ctx, n, x.ty, stack); }
        return;
    }
    if x.tag == N_MEMBER && x.flags & 1024 != 0 { push_tag(ctx, stack, x.symbol); return; }
    let v = c_decay(ctx, c_expression(ctx, n));
    if v.ty == dest.ty { emit(ctx, str("  gg_push(", stack, ", ", v.code, ", (size_t)gg_size_", dest.ty, "(", v.code, "));\n")); return; }
    if is_variant(ctx, v.ty) {
        push_tag(ctx, stack, v.ty);
        if ctx.types[v.ty].size_class == 1 { emit(ctx, str("  gg_push(", stack, ", ", v.code, ", (size_t)gg_size_", v.ty, "(", v.code, "));\n")); }
        else if stored_payload(ctx, v.ty) { let s = snapshot(ctx, v); emit(ctx, str("  gg_push(", stack, ", &", s.code, ", sizeof(", s.code, "));\n")); }
        return;
    }
    // The fixed mode: the tag selects how many payload bytes follow.
    let s = snapshot(ctx, v);
    emit(ctx, str("  switch ((", s.code, ").tag) {\n"));
    var e = ctx.types[v.ty].first;
    while e >= 0 {
        let vt = ctx.edges[e].value;
        emit(ctx, str("  case ", ctx.types[vt].count, ":")); push_tag(ctx, stack, vt);
        if stored_payload(ctx, vt) { emit(ctx, str("  gg_push(", stack, ", &(", s.code, ").u.v", ctx.types[vt].count, ", sizeof((", s.code, ").u.v", ctx.types[vt].count, "));\n")); }
        emit(ctx, "  break;\n"); e = ctx.edges[e].next;
    }
    emit(ctx, "  }\n");
}
// An enum match switches on the tag and copies a bound payload; an integer
// match tests its arms in order, each pattern a value or a half-open range.
recursive fn c_match(ctx: Compiler&, n: i64, dest: CValue) {
    let x = ctx.nodes[n];
    let s = snapshot(ctx, c_decay(ctx, c_expression(ctx, x.a)));
    let enumerated = ctx.types[s.ty].kind == T_ENUM;
    if enumerated { emit(ctx, str("  switch (", c_tag(ctx, s), ") {\n")); }
    var e = x.first; var first = true;
    while e >= 0 {
        let arm = ctx.nodes[ctx.edges[e].value];
        if enumerated {
            if arm.flags & 2 != 0 { emit(ctx, "  default:"); }
            var p = arm.first;
            while p >= 0 { emit(ctx, str("  case ", ctx.types[ctx.nodes[ctx.edges[p].value].symbol].count, ":")); p = ctx.edges[p].next; }
            emit(ctx, " {\n");
            if arm.b >= 0 { emit(ctx, str("  ", c_symbol(ctx, ctx.nodes[arm.b].symbol), " = ", c_payload(ctx, s, ctx.nodes[first_child(ctx, ctx.edges[e].value)].symbol, arm.flags & 1 != 0), ";\n")); }
            c_into(ctx, arm.c, dest);
            emit(ctx, "  break; }\n");
        } else {
            if !first { emit(ctx, " else "); } else { emit(ctx, "  "); }
            if arm.flags & 2 == 0 {
                emit(ctx, "if (0");
                let scalar = c_type(ctx, s.ty);
                var p = arm.first;
                while p >= 0 {
                    let item = ctx.nodes[ctx.edges[p].value];
                    if item.tag == N_RANGE { emit(ctx, str(" || ((", s.code, ") >= ((", scalar, ")UINT64_C(", ctx.nodes[item.a].bits, ")) && (", s.code, ") < ((", scalar, ")UINT64_C(", ctx.nodes[item.b].bits, ")))")); }
                    else { emit(ctx, str(" || (", s.code, ") == ((", scalar, ")UINT64_C(", item.bits, "))")); }
                    p = ctx.edges[p].next;
                }
                emit(ctx, ") ");
            }
            emit(ctx, "{\n"); c_into(ctx, arm.c, dest); emit(ctx, "  }");
        }
        first = false; e = ctx.edges[e].next;
    }
    emit(ctx, if enumerated { "  }\n" } else { "\n" });
}

// Limited arrays grow and shrink within their capacity, in place.
recursive fn c_limited_call(ctx: Compiler&, n: i64) -> CValue {
    let x = ctx.nodes[n]; let callee = ctx.nodes[x.a]; let builtin = x.symbol;
    let ty = decay(ctx, value_of(ctx, callee.a)).ty; let element = ctx.types[ty].element;
    let original = c_decay(ctx, c_expression(ctx, callee.a));
    var array = original;
    if ctx.types[ty].count >= 0 {
        let p = raw_temporary(ctx, save_text(ctx, str(c_type(ctx, ty), " *"))); emit(ctx, str("  ", p, " = ", original.address, ";\n"));
        array = CValue { code: save_text(ctx, str("(*", p, ")")), ty: ty, address: p, stack: "" };
    } else {
        let p = raw_temporary(ctx, "uint8_t *"); emit(ctx, str("  ", p, " = ", original.code, ";\n"));
        array = CValue { code: p, ty: ty, address: p, stack: "" };
    }
    let parts = limited_parts(ctx, array);
    let size = c_element_size(ctx, element);
    let common = save_text(ctx, str(parts.length, ", ", parts.width));
    let arg = first_child(ctx, n);
    if builtin == -10 {
        let v = snapshot(ctx, converted(ctx, c_expression(ctx, arg), element));
        let slot = raw_temporary(ctx, c_type(ctx, x.ty));
        emit(ctx, str("  ", slot, " = (", c_type(ctx, x.ty), ")gg_lpush(", common, ", ", parts.cap, ", ", parts.data, ", ", size, ");\n  *", slot, " = ", v.code, ";\n"));
        return CValue { code: slot, ty: x.ty, address: "", stack: "" };
    }
    if builtin == -11 {
        let v = snapshot(ctx, c_expression(ctx, arg));
        emit(ctx, str("  gg_lappend(", common, ", ", parts.cap, ", ", parts.data, ", ", size, ", ", c_view(ctx, v), ");\n"));
    } else if builtin == -12 {
        let count = snapshot(ctx, converted(ctx, c_expression(ctx, arg), default_integer(ctx))); let e = ctx.edges[x.first].next;
        var fill = save_text(ctx, "NULL");
        if e >= 0 { let value = snapshot(ctx, converted(ctx, c_expression(ctx, ctx.edges[e].value), element)); fill = save_text(ctx, str("&", value.code)); }
        emit(ctx, str("  gg_lresize(", common, ", ", parts.cap, ", ", parts.data, ", ", size, ", ", count.code, ", ", fill, ");\n"));
    } else if builtin == -13 { emit(ctx, str("  gg_lset(", common, ", 0);\n")); }
    else if builtin == -15 {
        let count = snapshot(ctx, converted(ctx, c_expression(ctx, arg), default_integer(ctx)));
        emit(ctx, str("  gg_lpop_n(", common, ", ", count.code, ");\n"));
    } else {
        let result = temporary(ctx, element);
        emit(ctx, str("  ", result, " = *(", c_type(ctx, element), " *)gg_lpop(", common, ", ", parts.data, ", ", size, ");\n"));
        return CValue { code: result, ty: element, address: save_text(ctx, str("&", result)), stack: "" };
    }
    return no_c_value(ctx);
}
fn dispatched_parameter(ctx: Compiler&, params: i64, place: i64) -> i64 {
    var p = ctx.nodes[params].first;
    for i in place { p = ctx.edges[p].next; }
    return p;
}
// Every argument is evaluated once, then the tag selects the case, which is
// given the payload in the dispatched argument's place.
recursive fn c_dispatch(ctx: Compiler&, n: i64) -> CValue {
    let x = ctx.nodes[n];
    let first = ctx.specializations[ctx.edges[x.c].value];
    let arguments = ctx.c_arguments;
    let argument_mark = arguments.len;
    var scrutinee = no_c_value(ctx);
    var e = x.first; var p = ctx.nodes[first.parameters].first; var i = 0;
    while e >= 0 {
        if i == x.b { scrutinee = snapshot(ctx, c_decay(ctx, c_expression(ctx, ctx.edges[e].value))); arguments.push(scrutinee.code); }
        else {
            let expected = ctx.symbols[ctx.nodes[ctx.edges[p].value].symbol].ty;
            arguments.push(snapshot(ctx, converted(ctx, c_expression(ctx, ctx.edges[e].value), expected)).code);
        }
        e = ctx.edges[e].next; p = ctx.edges[p].next; i++;
    }
    let ret = if first.result != 0 { temporary(ctx, first.result) } else { "" };
    emit(ctx, str("  switch (", c_tag(ctx, scrutinee), ") {\n"));
    var cases = x.c; var variant = ctx.types[scrutinee.ty].first;
    while cases >= 0 {
        let id = ctx.edges[cases].value; let vt = ctx.edges[variant].value;
        let spec = ctx.specializations[id];
        emit(ctx, str("  case ", ctx.types[vt].count, ": "));
        if ret.len > 0 { emit(ctx, str(ret, " = ")); }
        emit_ref(ctx, "gg_function_", id); emit(ctx, "(");
        for k in argument_mark..arguments.len {
            if k > argument_mark { emit(ctx, ", "); }
            if k - argument_mark == x.b { emit(ctx, c_payload(ctx, scrutinee, vt, ctx.types[ctx.symbols[ctx.nodes[ctx.edges[dispatched_parameter(ctx, spec.parameters, x.b)].value].symbol].ty].kind == T_REFERENCE)); }
            else { emit(ctx, arguments[k]); }
        }
        if argument_mark < arguments.len { emit(ctx, ", "); }
        let parent = ctx.scopes[ctx.symbols[spec.symbol].scope].function;
        if parent >= 0 { emit(ctx, str(c_frame(ctx, parent), ", ")); }
        emit(ctx, str("frame.base + ", ctx.c_slots, "); break;\n"));
        cases = ctx.edges[cases].next; variant = ctx.edges[variant].next;
    }
    emit(ctx, "  }\n");
    arguments.resize(argument_mark);
    return CValue { code: ret, ty: first.result, address: save_text(ctx, str("&", ret)), stack: "" };
}
recursive fn c_call(ctx: Compiler&, n: i64, destination: CValue) -> CValue {
    let x = ctx.nodes[n];
    let callee = ctx.nodes[x.a];
    let builtin = x.symbol;
    if builtin <= -10 && builtin >= -15 && ctx.types[decay(ctx, value_of(ctx, callee.a)).ty].flags == 2 { return c_limited_call(ctx, n); }
    if builtin <= -10 && builtin >= -15 {
        let original = c_expression(ctx, callee.a);
        let receiver = snapshot(ctx, CValue { code: c_reference(ctx, original), ty: reference_type(ctx, decay(ctx, value_of(ctx, callee.a)).ty, false), address: "", stack: "" });
        let array = c_decay(ctx, receiver); let element = element_type(ctx, array.ty);
        let ref = c_reference(ctx, array);
        let arg = first_child(ctx, n);
        if ctx.types[element].size_class == 1 {
            // A sequential array: elements are built or copied at its top.
            if builtin == -10 {
                let start = raw_temporary(ctx, "uint8_t *");
                emit(ctx, str("  ", start, " = ", array.stack, "->base + ", array.stack, "->top;\n"));
                c_build(ctx, arg, CValue { code: start, ty: element, address: start, stack: array.stack });
                emit(ctx, str("  (", array.code, ").len++;\n"));
                return CValue { code: start, ty: x.ty, address: "", stack: "" };
            }
            let v = snapshot(ctx, c_expression(ctx, arg)); let view = raw_temporary(ctx, "gg_slice");
            emit(ctx, str("  ", view, " = ", c_view(ctx, v), ";\n  gg_push(", array.stack, ", ", view, ".data, (size_t)gg_span_", element, "(", view, ".data, ", view, ".len)); (", array.code, ").len += ", view, ".len;\n"));
            return no_c_value(ctx);
        }
        if builtin == -15 {
            let count = snapshot(ctx, converted(ctx, c_expression(ctx, arg), default_integer(ctx)));
            emit(ctx, str("  gg_rpop_n(", ref, ", ", count.code, ", ", c_element_size(ctx, element), ");\n"));
            return no_c_value(ctx);
        }
        if builtin == -10 {
            let v = snapshot(ctx, converted(ctx, c_expression(ctx, arg), element));
            emit(ctx, str("  gg_append(", ref, ", &", v.code, ", 1, sizeof(", c_type(ctx, element), "));\n"));
            return CValue { code: save_text(ctx, str("((", c_type(ctx, element), " *)(", array.code, ").base) + (", array.code, ").len - 1")), ty: x.ty, address: "", stack: "" };
        }
        if builtin == -11 {
            let v = snapshot(ctx, c_expression(ctx, arg)); let view = c_view(ctx, v);
            emit(ctx, str("  gg_append(", ref, ", (", view, ").data, (", view, ").len, sizeof(", c_type(ctx, element), "));\n"));
        } else if builtin == -12 {
            let count = snapshot(ctx, c_decay(ctx, c_expression(ctx, arg))); let e = ctx.edges[ctx.nodes[n].first].next;
            if e >= 0 { let fill = snapshot(ctx, converted(ctx, c_expression(ctx, ctx.edges[e].value), element)); emit(ctx, str("  gg_resize(", ref, ", ", count.code, ", sizeof(", c_type(ctx, element), "), &", fill.code, ");\n")); }
            else { emit(ctx, str("  gg_resize(", ref, ", ", count.code, ", sizeof(", c_type(ctx, element), "), NULL);\n")); }
        } else if builtin == -13 { emit(ctx, str("  gg_resize(", ref, ", 0, sizeof(", c_type(ctx, element), "), NULL);\n")); }
        else {
            let result = temporary(ctx, element);
            emit(ctx, str("  ", result, " = *(", c_type(ctx, element), " *)gg_rpop(", ref, ", ", c_element_size(ctx, element), ");\n  gg_resize(", ref, ", (", array.code, ").len-1, sizeof(", c_type(ctx, element), "), NULL);\n"));
            return CValue { code: result, ty: element, address: save_text(ctx, str("&", result)), stack: "" };
        }
        return no_c_value(ctx);
    }
    if builtin == -20 || builtin == -21 || builtin == -22 {
        var out = destination; var e = x.first;
        if builtin == -22 { out = c_expression(ctx, ctx.edges[e].value); e = ctx.edges[e].next; }
        else if out.ty == 0 { out = c_array_temp(ctx, array_type(ctx, integer_type(ctx, 1, true), 3, -1)); }
        while e >= 0 { c_render(ctx, out, c_expression(ctx, ctx.edges[e].value)); e = ctx.edges[e].next; }
        if builtin == -20 { emit(ctx, str("  gg_append(", c_reference(ctx, out), ", \"\\n\", 1, 1);\n  gg_write(stdout, ", c_view(ctx, out), ");\n")); return no_c_value(ctx); }
        if builtin == -22 { return no_c_value(ctx); }
        return out;
    }
    if builtin == -28 { return CValue { code: save_text(ctx, str("((int64_t)", ctx.tokens[x.bits as i64].line, ")")), ty: x.ty, address: "", stack: "" }; }
    if builtin == -29 {
        let path = ctx.sources[ctx.tokens[x.bits as i64].file].path;
        var base = 0; for c, i in path { if c == '/' || c == '\\' { base = i + 1; } }
        return CValue { code: save_text(ctx, str("gg_view((void *)", c_literal(ctx, path[base..]), ", ", path.len - base, ")")), ty: x.ty, address: "", stack: "" };
    }
    if builtin == -30 {
        let a = c_decay(ctx, c_expression(ctx, first_child(ctx, n))); let view = raw_temporary(ctx, "gg_slice");
        emit(ctx, str("  ", view, " = ", c_view(ctx, a), "; ", view, ".len *= sizeof(", c_type(ctx, element_type(ctx, a.ty)), ");\n"));
        return CValue { code: view, ty: x.ty, address: "", stack: "" };
    }
    if builtin == -27 {
        let name = temporary(ctx, x.ty); emit(ctx, str("  memset(&", name, ", 0, sizeof(", name, "));\n"));
        return CValue { code: name, ty: x.ty, address: save_text(ctx, str("&", name)), stack: "" };
    }
    if builtin <= -23 && builtin >= -26 {
        let arg = c_decay(ctx, c_expression(ctx, first_child(ctx, n)));
        if builtin == -26 {
            if ctx.types[arg.ty].size_class == 2 {
                var dest = destination; if dest.ty == 0 { dest = c_array_temp(ctx, arg.ty); }
                let view = c_view(ctx, arg);
                emit(ctx, str("  gg_append(", c_reference(ctx, dest), ", (", view, ").data, (", view, ").len, sizeof(", c_type(ctx, element_type(ctx, arg.ty)), "));\n"));
                return dest;
            }
            if ctx.types[arg.ty].size_class == 1 {
                let built = c_variable_temp(ctx, arg.ty);
                emit(ctx, str("  gg_push(", built.stack, ", ", arg.code, ", (size_t)gg_size_", arg.ty, "(", arg.code, "));\n"));
                return built;
            }
            return snapshot(ctx, arg);
        }
        if builtin == -23 { emit(ctx, str("  if (!(", arg.code, ")) gg_fail(\"assertion failed\");\n")); }
        if builtin == -24 { emit(ctx, str("  gg_write(stderr, ", c_view(ctx, arg), "); gg_fail(\"abort\");\n")); }
        if builtin == -25 { emit(ctx, str("  exit((int)(", arg.code, "));\n")); }
        return no_c_value(ctx);
    }
    if builtin == -40 { return c_dispatch(ctx, n); }
    let spec = ctx.specializations[builtin]; let decl = ctx.nodes[ctx.symbols[spec.symbol].decl];
    let params = spec.parameters;
    // Borrow once: the watermark and restore share a stable reference path.
    let arguments = ctx.c_arguments;
    let argument_mark = arguments.len;
    var e = x.first; var p = ctx.nodes[params].first;
    while e >= 0 {
        let expected = ctx.symbols[ctx.nodes[ctx.edges[p].value].symbol].ty;
        if ctx.types[expected].size_class == 1 {
            let built = c_variable_temp(ctx, expected); c_into(ctx, ctx.edges[e].value, built);
            arguments.push(built.code);
        } else {
            let value = snapshot(ctx, converted(ctx, c_expression(ctx, ctx.edges[e].value), expected));
            arguments.push(value.code);
        }
        e = ctx.edges[e].next; p = ctx.edges[p].next;
    }
    var dest = destination;
    if ctx.types[spec.result].size_class == 1 && dest.ty == 0 { dest = c_variable_temp(ctx, spec.result); }
    if ctx.types[spec.result].size_class == 2 && dest.ty == 0 { dest = c_array_temp(ctx, spec.result); }
    let multiple = child_count(ctx, spec.results) > 1;
    if multiple { ctx.c_multis.push(n); ctx.c_multis.push(0); }
    let ret = if multiple { c_multi(ctx, n) } else if spec.result != 0 && ctx.types[spec.result].size_class == 0 { temporary(ctx, spec.result) } else { "" };
    if multiple { declare_ref(ctx, "  gg_results_", builtin); format(ctx.c_declarations, " ", ret, ";\n"); }
    emit(ctx, "  "); if ret.len > 0 { emit(ctx, str(ret, " = ")); }
    if decl.flags & 2 != 0 { emit(ctx, if decl.symbol >= 0 { ctx.tokens[decl.symbol].text } else { ctx.tokens[decl.token].text }); }
    else { emit_ref(ctx, "gg_function_", builtin); }
    emit(ctx, "(");
    var comma = false;
    for i in argument_mark..arguments.len {
        if comma { emit(ctx, ", "); } comma = true;
        emit(ctx, arguments[i]);
    }
    arguments.resize(argument_mark);
    if decl.flags & 2 == 0 {
        let parent = ctx.scopes[ctx.symbols[spec.symbol].scope].function;
        if parent >= 0 { if comma { emit(ctx, ", "); } emit(ctx, c_frame(ctx, parent)); comma = true; }
        if ctx.types[spec.result].size_class == 1 { if comma { emit(ctx, ", "); } emit(ctx, str("gg_ref(NULL, ", dest.stack, ")")); comma = true; }
        if ctx.types[spec.result].size_class == 2 { if comma { emit(ctx, ", "); } emit(ctx, c_reference(ctx, dest)); comma = true; }
        if comma { emit(ctx, ", "); } emit(ctx, str("frame.base + ", ctx.c_slots));
    }
    emit(ctx, ");\n");
    if ctx.types[spec.result].size_class > 0 { return dest; }
    if multiple { return c_result_field(ctx, ret, spec.result, 0); }
    return CValue { code: ret, ty: spec.result, address: save_text(ctx, str("&", ret)), stack: "" };
}

recursive fn c_statement(ctx: Compiler&, n: i64) {
    let x = ctx.nodes[n];
    if x.tag == N_FUNCTION { return; }
    if x.tag == N_RECEIVE {
        c_expression(ctx, x.a);
        var e = x.first;
        while e >= 0 { c_statement(ctx, ctx.edges[e].value); e = ctx.edges[e].next; }
        return;
    }
    if x.tag == N_BIND {
        let symbol = ctx.nodes[first_child(ctx, n)].symbol;
        let dest = symbol_value(ctx, symbol);
        if ctx.types[dest.ty].size_class == 2 && (ctx.c_function < 0 || ctx.return_locals[ctx.c_function] != symbol) {
            emit(ctx, str("  ", dest.stack, "->top = 0;\n  ", dest.code, ".base = ", dest.stack, "->base; ", dest.code, ".len = 0;\n"));
        }
        if ctx.types[dest.ty].size_class == 1 { emit(ctx, str("  ", dest.stack, "->top = 0; ", dest.code, " = ", dest.stack, "->base;\n")); }
        let init = first_child(ctx, x.b); if init >= 0 { c_into(ctx, init, dest); }
        return;
    }
    if x.tag == N_RETURN {
        if x.b >= 0 { c_expression(ctx, x.b); }
        var e = x.first; var index = 0;
        while e >= 0 {
            let dest = if child_count(ctx, ctx.specializations[ctx.c_function].results) > 1 { c_return_value(ctx, index) } else { ctx.c_result };
            c_into(ctx, ctx.edges[e].value, dest); e = ctx.edges[e].next; index++;
        }
        emit(ctx, "  goto gg_done;\n"); return;
    }
    if x.tag == N_BREAK || x.tag == N_CONTINUE {
        var control = ctx.c_controls.len - 1;
        if x.tag == N_CONTINUE { while control >= 0 && ctx.c_controls[control].again < 0 { control--; } }
        if control < 0 { abort("internal error: no loop target"); }
        let label = if x.tag == N_CONTINUE { ctx.c_controls[control].again } else { ctx.c_controls[control].done };
        if x.first >= 0 { c_into(ctx, first_child(ctx, n), control_destination(ctx, control)); }
        emit(ctx, str("  goto label", label, ";\n")); return;
    }
    if x.tag == N_ASSIGN {
        let raw = c_expression(ctx, x.a); let dest = c_decay(ctx, raw); let op = ctx.tokens[x.token].text;
        if op == "=" && ctx.types[dest.ty].kind == T_ARRAY && ctx.types[dest.ty].flags == 2 && ctx.types[dest.ty].count < 0 {
            let v = c_decay(ctx, c_expression(ctx, x.b));
            emit(ctx, str("  gg_dyn_assign(", dest.code, ", ", c_view(ctx, v), ", ", c_element_size(ctx, ctx.types[dest.ty].element), ");\n")); return;
        }
        if op == "=" { c_into(ctx, x.b, dest); return; }
        if op == ".=" { let rhs = c_expression(ctx, x.b); emit(ctx, str("  ", raw.code, " = ", c_reference(ctx, rhs), ";\n")); return; }
        let old = snapshot(ctx, dest);
        var right = CValue { code: "1", ty: dest.ty, address: "", stack: "" };
        if x.b >= 0 { right = snapshot(ctx, converted(ctx, c_expression(ctx, x.b), dest.ty)); }
        let operation = if op == "++" { "+" } else if op == "--" { "-" } else { op[..op.len - 1] };
        emit(ctx, str("  ", dest.code, " = ", c_binary(ctx, operation, old, right, dest.ty), ";\n")); return;
    }
    if x.tag == N_WHILE || x.tag == N_LOOP || x.tag == N_EARLY || x.tag == N_FOR { c_loop(ctx, n, no_c_value(ctx)); return; }
    if x.tag == N_EXPR_STMT { c_into(ctx, x.a, no_c_value(ctx)); return; }
    c_into(ctx, n, no_c_value(ctx));
}
fn park_control(ctx: Compiler&, again: i64, done: i64, dest: CValue) -> Control {
    var c = Control { again: again, done: done, ty: dest.ty, code_len: dest.code.len, address_len: dest.address.len, stack_len: dest.stack.len };
    if dest.ty == 0 { c.code_len = 0; c.address_len = 0; c.stack_len = 0; return c; }
    c.code = ctx.text_storage.len; ctx.text_storage.append(dest.code);
    c.address = ctx.text_storage.len; ctx.text_storage.append(dest.address);
    c.stack = ctx.text_storage.len; ctx.text_storage.append(dest.stack);
    return c;
}
fn control_destination(ctx: Compiler&, i: i64) -> CValue {
    let c = ctx.c_controls[i];
    return CValue { code: ctx.text_storage[c.code..c.code + c.code_len], ty: c.ty, address: ctx.text_storage[c.address..c.address + c.address_len], stack: ctx.text_storage[c.stack..c.stack + c.stack_len] };
}
// Loops and blocks jump to their labels; a break with a value fills dest.
recursive fn c_loop(ctx: Compiler&, n: i64, dest: CValue) {
    let x = ctx.nodes[n];
    let controls = ctx.c_controls;
    let control_mark = controls.len;
    let start = ctx.c_label; let advance = ctx.c_label + 1; let done = ctx.c_label + 2; ctx.c_label += 3;
    if x.tag != N_FOR { controls.push(park_control(ctx, if x.tag == N_EARLY { -1 } else { advance }, done, dest)); }
    if x.tag == N_FOR {
        let index = raw_temporary(ctx, "int64_t");
        var iterable = no_c_value(ctx); var upper = no_c_value(ctx);
        var cursor = save_text(ctx, "");
        let range = ctx.nodes[x.b].tag == N_RANGE;
        if range {
            let lo = snapshot(ctx, c_decay(ctx, c_expression(ctx, ctx.nodes[x.b].a))); upper = snapshot(ctx, c_decay(ctx, c_expression(ctx, ctx.nodes[x.b].b)));
            emit(ctx, str("  ", index, " = ", lo.code, ";\n"));
        } else {
            iterable = c_decay(ctx, c_expression(ctx, x.b));
            if ctx.types[iterable.ty].kind == T_INTEGER { upper = snapshot(ctx, iterable); }
            emit(ctx, str("  ", index, " = 0;\n"));
            let elem = element_type(ctx, iterable.ty);
            if elem >= 0 && ctx.types[elem].size_class == 1 { cursor = raw_temporary(ctx, "uint8_t *"); emit(ctx, str("  ", cursor, " = (uint8_t *)(", c_view(ctx, iterable), ").data;\n")); }
        }
        // The input is evaluated before the loop catches breaks.
        controls.push(park_control(ctx, advance, done, dest));
        emit(ctx, str("label", start, ":;\n"));
        let symbol = ctx.nodes[x.a].symbol;
        if upper.ty != 0 {
            emit(ctx, str("  if (", index, " >= ", upper.code, ") goto label", done, ";\n  ", c_symbol(ctx, symbol), " = ", index, ";\n"));
        } else {
            let view = c_view(ctx, iterable); let elem = element_type(ctx, iterable.ty);
            emit(ctx, str("  if (", index, " >= (", view, ").len) goto label", done, ";\n  ", c_symbol(ctx, symbol), " = "));
            if cursor.len > 0 { emit(ctx, str(cursor, ";\n")); }
            else {
                if x.flags & 1 != 0 || ctx.types[elem].size_class > 0 { emit(ctx, "&"); }
                emit(ctx, str("((", c_type(ctx, elem), " *)(", view, ").data)[", index, "];\n"));
            }
        }
        if x.first >= 0 { emit(ctx, str("  ", c_symbol(ctx, ctx.nodes[ctx.edges[x.first].value].symbol), " = ", index, ";\n")); }
        c_statement(ctx, x.c);
        emit(ctx, str("label", advance, ":;\n"));
        if cursor.len > 0 { emit(ctx, str("  ", cursor, " += gg_size_", element_type(ctx, iterable.ty), "(", cursor, ");\n")); }
        emit(ctx, str("  ", index, "++; goto label", start, ";\n"));
    } else if x.tag == N_EARLY { c_into(ctx, x.a, dest); }
    else {
        emit(ctx, str("label", advance, ":;\n"));
        if x.tag == N_WHILE { let condition = c_decay(ctx, c_expression(ctx, x.a)); emit(ctx, str("  if (!(", condition.code, ")) goto label", done, ";\n")); c_statement(ctx, x.b); }
        else { c_statement(ctx, x.a); }
        emit(ctx, str("  goto label", advance, ";\n"));
    }
    emit(ctx, str("label", done, ":;\n")); controls.resize(control_mark); return;
}
recursive fn returned_local(ctx: Compiler&, n: i64, spec: i64) -> i64 {
    if n < 0 { return -1; }
    let x = ctx.nodes[n];
    if x.tag == N_FUNCTION { return -1; }
    if x.tag == N_RETURN {
        let arg = first_child(ctx, n);
        if arg < 0 || ctx.nodes[arg].tag != N_NAME { return -2; }
        let symbol = ctx.nodes[arg].symbol;
        if symbol < 0 || ctx.scopes[ctx.symbols[symbol].scope].function != spec { return -2; }
        return symbol;
    }
    var result = -1;
    for sub in [x.a, x.b, x.c] {
        let found = returned_local(ctx, sub, spec);
        if found == -2 || (found >= 0 && result >= 0 && found != result) { return -2; }
        if found >= 0 { result = found; }
    }
    var e = x.first;
    while e >= 0 {
        let found = returned_local(ctx, ctx.edges[e].value, spec);
        if found == -2 || (found >= 0 && result >= 0 && found != result) { return -2; }
        if found >= 0 { result = found; }
        e = ctx.edges[e].next;
    }
    return result;
}
fn c_signature(ctx: Compiler&, spec_id: i64) {
    let spec = ctx.specializations[spec_id]; let decl = ctx.nodes[ctx.symbols[spec.symbol].decl];
    emit(ctx, "static ");
    if child_count(ctx, spec.results) > 1 { emit_ref(ctx, "gg_results_", spec_id); }
    else { emit(ctx, if ctx.types[spec.result].size_class > 0 { "void" } else { c_type(ctx, spec.result) }); }
    emit_ref(ctx, " gg_function_", spec_id); emit(ctx, "(");
    var e = ctx.nodes[spec.parameters].first; var comma = false;
    while e >= 0 {
        let symbol = ctx.nodes[ctx.edges[e].value].symbol;
        if comma { emit(ctx, ", "); } comma = true;
        emit(ctx, str(c_type(ctx, ctx.symbols[symbol].ty), " p", ctx.local_names[symbol])); e = ctx.edges[e].next;
    }
    let parent = ctx.scopes[ctx.symbols[spec.symbol].scope].function;
    if parent >= 0 { if comma { emit(ctx, ", "); } emit_ref(ctx, "struct gg_frame_", parent); emit(ctx, " *parent"); comma = true; }
    if ctx.types[spec.result].size_class > 0 { if comma { emit(ctx, ", "); } emit(ctx, "gg_reference result"); comma = true; }
    if comma { emit(ctx, ", "); } emit(ctx, "int64_t base)");
}
fn c_globals(ctx: Compiler&) {
    emit(ctx, "static struct {\n  unsigned char dummy;\n");
    for s, i in ctx.symbols { if s.kind == 2 && s.ty >= 0 && global_storage(ctx, i) { emit(ctx, str("  ", c_type(ctx, s.ty), " ", c_name(ctx, i), ";\n")); } }
    emit(ctx, "} gg_globals;\n");
}
fn c_frame_struct(ctx: Compiler&, id: i64) {
    let spec = ctx.specializations[id];
    let parent = ctx.scopes[ctx.symbols[spec.symbol].scope].function;
    emit_ref(ctx, "struct gg_frame_", id); emit(ctx, " {\n  int64_t base;\n");
    if parent >= 0 { emit_ref(ctx, "  struct gg_frame_", parent); emit(ctx, " *parent;\n"); }
    if ctx.types[spec.result].size_class > 0 { emit(ctx, "  gg_reference result;\n"); }
    var symbol = ctx.first_local[id];
    while symbol >= 0 {
        if symbol != ctx.return_locals[id] { emit(ctx, str("  ", c_type(ctx, ctx.symbols[symbol].ty), " ", c_name(ctx, symbol), ";\n")); }
        symbol = ctx.next_local[symbol];
    }
    emit(ctx, "};\n");
    if child_count(ctx, spec.results) > 1 {
        emit(ctx, "typedef struct {\n");
        var re = ctx.nodes[spec.results].first; var index = 0;
        while re >= 0 { emit(ctx, str("  ", c_type(ctx, ctx.nodes[ctx.edges[re].value].ty), " r", index, ";\n")); re = ctx.edges[re].next; index++; }
        emit_ref(ctx, "} gg_results_", id); emit(ctx, ";\n");
    }
    c_signature(ctx, id); emit(ctx, ";\n");
}
fn prepare_emission(ctx: Compiler&) {
    // Rendering itself uses byte types; close that dependency before emitting
    // the helper prototypes rather than discovering it in their bodies.
    integer_type(ctx, 1, true);
    for ty in ctx.types { ctx.c_type_state.push(0); }
    var last_local: i64[>..] = [];
    for spec, i in ctx.specializations {
        ctx.function_slots.push(0); ctx.first_local.push(-1); last_local.push(-1);
        var returned = -1;
        if ctx.types[spec.result].size_class == 2 { returned = returned_local(ctx, spec.body, i); }
        ctx.return_locals.push(returned);
    }
    for s, i in ctx.symbols {
        var slot = -1;
        let owned_variable = s.kind == 2 && s.ty >= 0 && ctx.types[s.ty].size_class == 1 && s.decl >= 0 && ctx.nodes[s.decl].tag == N_BIND;
        if owned_variable || (s.kind == 2 && s.ty >= 0 && ctx.types[s.ty].size_class == 2) {
            if global_storage(ctx, i) { slot = ctx.c_global_slots; ctx.c_global_slots++; }
            else { let owner = ctx.scopes[s.scope].function; if ctx.return_locals[owner] != i { slot = ctx.function_slots[owner]; ctx.function_slots[owner]++; } }
        }
        ctx.symbol_slots.push(slot);
        // Frame fields in symbol order, numbered within their owner.
        var local = -1;
        if s.kind == 2 && s.scope != 0 && ctx.scopes[s.scope].function >= 0 {
            let owner = ctx.scopes[s.scope].function;
            if last_local[owner] < 0 { ctx.first_local[owner] = i; local = 0; }
            else { ctx.next_local[last_local[owner]] = i; local = ctx.local_names[last_local[owner]] + 1; }
            last_local[owner] = i;
        }
        ctx.local_names.push(local); ctx.next_local.push(-1);
    }
}
// Each specialization's text goes to c_specs: its frame struct and prototype,
// then (at c_spec_split) its definition. c_output and c_declarations are
// append-only scratch: the checker cannot prove nothing slices into them.
fn spec_text(ctx: Compiler&, mark: i64) -> i64 { ctx.c_specs.append(ctx.c_output[mark..]); return ctx.c_output.len; }
fn emit_function(ctx: Compiler&, id: i64) {
    let spec = ctx.specializations[id]; let decl = ctx.nodes[ctx.symbols[spec.symbol].decl];
    ctx.c_spec_start.push(ctx.c_specs.len);
    if decl.flags & 2 != 0 { ctx.c_spec_split.push(ctx.c_specs.len); return; }
    ctx.c_function = id; ctx.c_slots = ctx.function_slots[id]; ctx.c_temporary = 0; ctx.c_label = 0;
    let multis = ctx.c_multis; multis.clear();
    var mark = ctx.c_output.len;
    let declaration_start = ctx.c_declarations.len;
    c_frame_struct(ctx, id); mark = spec_text(ctx, mark);
    ctx.c_spec_split.push(ctx.c_specs.len);
    c_signature(ctx, id); emit(ctx, " {\n"); emit_ref(ctx, "  struct gg_frame_", id); emit(ctx, " frame;\n");
    mark = spec_text(ctx, mark);
    emit(ctx, "  frame.base = base;\n");
    if ctx.scopes[ctx.symbols[spec.symbol].scope].function >= 0 { emit(ctx, "  frame.parent = parent;\n"); }
    if child_count(ctx, spec.results) > 1 {
        declare_ref(ctx, "  gg_results_", id); ctx.c_declarations.append(" gg_return;\n");
        ctx.c_result = c_return_value(ctx, 0);
    } else if ctx.types[spec.result].size_class == 1 {
        // The caller marked where the result starts; the body appends it.
        emit(ctx, "  frame.result = result;\n");
        ctx.c_result = CValue { code: "", ty: spec.result, address: "", stack: "result.stack" };
    } else if ctx.types[spec.result].size_class > 0 {
        emit(ctx, "  frame.result = result;\n");
        ctx.c_result = CValue { code: "(*result.header)", ty: spec.result, address: "result.header", stack: "result.stack" };
    } else if spec.result != 0 {
        let name = temporary(ctx, spec.result);
        ctx.c_result = CValue { code: name, ty: spec.result, address: save_text(ctx, str("&", name)), stack: "" };
    } else { ctx.c_result = no_c_value(ctx); }
    var e = ctx.nodes[spec.parameters].first;
    while e >= 0 { let symbol = ctx.nodes[ctx.edges[e].value].symbol; emit(ctx, str("  ", c_symbol(ctx, symbol), " = p", ctx.local_names[symbol], ";\n")); e = ctx.edges[e].next; }
    c_into(ctx, spec.body, ctx.c_result);
    emit(ctx, "gg_done:;\n");
    if ctx.c_slots > 0 {
        let k = raw_temporary(ctx, "int64_t"); emit(ctx, str("  for (", k, " = 0; ", k, " < ", ctx.c_slots, "; ", k, "++) gg_stacks[base + ", k, "].top = 0;\n"));
    }
    if spec.result != 0 && ctx.types[spec.result].size_class == 0 { emit(ctx, str("  return ", if child_count(ctx, spec.results) > 1 { "gg_return" } else { ctx.c_result.code }, ";\n")); }
    emit(ctx, "}\n");
    ctx.c_specs.append(ctx.c_declarations[declaration_start..]);
    spec_text(ctx, mark);
}
// Specializations that differ only in provenance spell the same C. Rewrite
// each marker to byte 1 in place, listing its target in refs (chunk k's are
// refs[ref_start[k]..ref_start[k + 1]]); chunk count is the program body.
fn compact_refs(ctx: Compiler&, refs: i64[>..]&, ref_start: i64[>..]&) {
    let chunks = ctx.c_spec_start.len - 1;
    var w = 0;
    for k in 0..chunks {
        let begin = ctx.c_spec_start[k]; let end = ctx.c_spec_start[k + 1]; let split = ctx.c_spec_split[k];
        ctx.c_spec_start[k] = w; ref_start.push(refs.len);
        var r = begin;
        while r < end {
            if r == split { ctx.c_spec_split[k] = w; }
            let c = ctx.c_specs[r];
            ctx.c_specs[w] = c; w++; r++;
            if c == 1 {
                var id = 0;
                while ctx.c_specs[r] != 2 { id = id * 10 + (ctx.c_specs[r] - '0'); r++; }
                r++; refs.push(id);
            }
        }
        if split == end { ctx.c_spec_split[k] = w; }
    }
    ctx.c_spec_start[chunks] = w; ref_start.push(refs.len);
}
fn same_text(ctx: Compiler&, a: i64, b: i64) -> bool {
    let a0 = ctx.c_spec_start[a]; let a1 = ctx.c_spec_start[a + 1];
    let b0 = ctx.c_spec_start[b]; let b1 = ctx.c_spec_start[b + 1];
    if a1 - a0 != b1 - b0 || ctx.c_spec_split[a] - a0 != ctx.c_spec_split[b] - b0 { return false; }
    return ctx.c_specs[a0..a1] == ctx.c_specs[b0..b1];
}
fn same_key(classes: const i64[:], refs: const i64[:], ref_start: const i64[:], a: i64, b: i64) -> bool {
    if classes[a] != classes[b] { return false; }
    let n = ref_start[a + 1] - ref_start[a];
    if n != ref_start[b + 1] - ref_start[b] { return false; }
    for i in 0..n { if classes[refs[ref_start[a] + i]] != classes[refs[ref_start[b] + i]] { return false; } }
    return true;
}
// Copies text[begin..end] to the output, spelling each marker as the
// representative of its target; returns the next unread ref.
fn write_resolved(ctx: Compiler&, begin: i64, end: i64, refs: const i64[:], first: i64, rep: const i64[:]) -> i64 {
    var run = begin; var r = first;
    for i in begin..end {
        if ctx.c_specs[i] == 1 {
            ctx.c_final.append(ctx.c_specs[run..i]); format(ctx.c_final, rep[refs[r]]); r++; run = i + 1;
        }
    }
    ctx.c_final.append(ctx.c_specs[run..end]);
    return r;
}
// Partition refinement to a fixed point: the coarsest partition is equal text
// with markers blanked; each round splits a class by its targets' classes.
// It only ever splits, so an unchanged class count is the fixed point.
fn write_specializations(ctx: Compiler&) {
    let count = ctx.specializations.len;
    var refs: i64[>..] = []; var ref_start: i64[>..] = [];
    compact_refs(ctx, refs, ref_start);
    var size = 1; while size < 2 * count + 2 { size *= 2; }
    let mask = size - 1;
    var table: i64[>..] = []; table.resize(size, -1);
    var hashes: u64[>..] = []; var classes: i64[>..] = []; var refined: i64[>..] = [];
    var class_count = 0;
    for k in 0..count {
        var h: u64 = 14695981039346656037;
        for i in ctx.c_spec_start[k]..ctx.c_spec_start[k + 1] { h = (h ^ ctx.c_specs[i]) * 1099511628211; }
        h = (h ^ ((ctx.c_spec_split[k] - ctx.c_spec_start[k]) as u64)) * 1099511628211;
        hashes.push(h); refined.push(-1);
        if ctx.c_spec_start[k] == ctx.c_spec_start[k + 1] { classes.push(-1); continue; }
        var slot = (h as i64) & mask; var found = -1;
        while table[slot] >= 0 {
            let other = table[slot];
            if hashes[other] == h && same_text(ctx, other, k) { found = classes[other]; break; }
            slot = (slot + 1) & mask;
        }
        if found < 0 { found = class_count; class_count++; table[slot] = k; }
        classes.push(found);
    }
    while true {
        for i in 0..size { table[i] = -1; }
        var next_count = 0;
        for k in 0..count {
            if classes[k] < 0 { continue; }
            var h: u64 = (14695981039346656037 ^ (classes[k] as u64)) * 1099511628211;
            for i in ref_start[k]..ref_start[k + 1] { h = (h ^ (classes[refs[i]] as u64)) * 1099511628211; }
            hashes[k] = h;
            var slot = (h as i64) & mask; var found = -1;
            while table[slot] >= 0 {
                let other = table[slot];
                if hashes[other] == h && same_key(classes, refs, ref_start, other, k) { found = refined[other]; break; }
                slot = (slot + 1) & mask;
            }
            if found < 0 { found = next_count; next_count++; table[slot] = k; }
            refined[k] = found;
        }
        for k in 0..count { if classes[k] >= 0 { classes[k] = refined[k]; } }
        if next_count == class_count { break; }
        class_count = next_count;
    }
    // The first specialization of each class represents it.
    var first: i64[>..] = []; first.resize(class_count, -1);
    var rep: i64[>..] = [];
    for k in 0..count {
        if classes[k] >= 0 && first[classes[k]] < 0 { first[classes[k]] = k; }
        rep.push(if classes[k] >= 0 { first[classes[k]] } else { k });
    }
    var split_ref: i64[>..] = [];
    for k in 0..count {
        split_ref.push(ref_start[k]);
        if rep[k] == k { split_ref[k] = write_resolved(ctx, ctx.c_spec_start[k], ctx.c_spec_split[k], refs, ref_start[k], rep); }
    }
    for k in 0..count { if rep[k] == k { write_resolved(ctx, ctx.c_spec_split[k], ctx.c_spec_start[k + 1], refs, split_ref[k], rep); } }
    write_resolved(ctx, ctx.c_spec_start[count], ctx.c_spec_start[count + 1], refs, ref_start[count], rep);
}
fn generate_c(ctx: Compiler&) {
    prepare_emission(ctx);
    ctx.c_final.append(runtime_source()); ctx.c_final.push('\n');
    let type_start = ctx.c_output.len;
    for t, id in ctx.types { emit_type(ctx, id); }
    c_format_helpers(ctx); c_globals(ctx); c_format_bodies(ctx); ctx.c_final.append(ctx.c_output[type_start..]);
    for spec, i in ctx.specializations { emit_function(ctx, i); }
    ctx.c_function = -1; ctx.c_slots = 0; ctx.c_temporary = 0; ctx.c_label = 0;
    let multis = ctx.c_multis; multis.clear();
    ctx.c_spec_start.push(ctx.c_specs.len); ctx.c_spec_split.push(ctx.c_specs.len);
    let wrappers = ctx.c_output.len; c_format_wrappers(ctx); spec_text(ctx, wrappers);
    let declaration_start = ctx.c_declarations.len; let body_start = ctx.c_output.len;
    emit(ctx, str("  struct { int64_t base; } frame;\n  frame.base = ", ctx.c_global_slots, ";\n  gg_argc = argc; gg_argv = argv;\n"));
    for n in ctx.global_order { c_statement(ctx, n); }
    var main_id = -1;
    for spec, i in ctx.specializations {
        let symbol = ctx.symbols[spec.symbol]; if symbol.ns < 0 && symbol.scope == 0 && ctx.tokens[symbol.token].text == "main" { main_id = i; }
    }
    emit_ref(ctx, "  gg_function_", main_id); emit(ctx, str("(frame.base + ", ctx.c_slots, ");\n  return 0;\n}\n"));
    ctx.c_specs.append("static int gg_program(int argc, char **argv) {\n");
    ctx.c_specs.append(ctx.c_declarations[declaration_start..]);
    spec_text(ctx, body_start);
    ctx.c_spec_start.push(ctx.c_specs.len);
    write_specializations(ctx);
    ctx.c_final.append("int main(int argc, char **argv) {\n#ifdef _MSC_VER\n  __try { return gg_program(argc, argv); }\n  __except (GetExceptionCode() == EXCEPTION_STACK_OVERFLOW ? EXCEPTION_EXECUTE_HANDLER : EXCEPTION_CONTINUE_SEARCH) {\n    _resetstkoflw(); gg_fail(\"native call stack overflow\"); return 1;\n  }\n#else\n  return gg_program(argc, argv);\n#endif\n}\n");
}

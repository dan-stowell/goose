// Structural equality and formatting are generated per semantic type, rather
// than comparing packed structs as opaque bytes (padding and floats matter).
fn render_field(ctx: Compiler&, ty: i64, code: const u8[:]) {
    if element_type(ctx, ty) == integer_type(ctx, 1, true) && ctx.types[ty].formatter < 0 {
        emit(ctx, str("gg_quote(out, ", c_view(ctx, CValue { code: code, ty: ty }), ");"));
    } else { emit(ctx, str("gg_render_", ty, "(out, ", code, ");")); }
}
// A payload-less variant renders as Enum.Variant; one with a payload as its literal.
fn render_constant(ctx: Compiler&, vt: i64) {
    let text = save_text(ctx, str(ctx.tokens[ctx.nodes[ctx.types[ctx.types[vt].element].decl].token].text, ".", ctx.tokens[ctx.nodes[ctx.types[vt].decl].token].text));
    emit(ctx, str("gg_append(out,", c_literal(ctx, text), ",", text.len, ",1);"));
}
// Packed layout walkers. A variable-size value's size is found by walking its
// parts: a stored length and its elements, or a struct's fields in order.
fn c_layout_helpers(ctx: Compiler&) {
    for t, id in ctx.types {
        if t.size_class == 1 {
            emit(ctx, str("static int64_t gg_size_", id, "(uint8_t *p);\nstatic int64_t gg_span_", id, "(uint8_t *p, int64_t n);\n"));
            if t.kind == T_STRUCT { emit(ctx, str("static uint8_t *gg_at_", id, "(uint8_t *p, int k);\n")); }
        }
    }
    for t, id in ctx.types {
        if limited_fixed(ctx, id) {
            let ct = c_type(ctx, id);
            emit(ctx, str("static ", ct, " gg_limit_", id, "(gg_slice s) { ", ct, " r; memset(&r, 0, sizeof r); if (s.len > ", t.count, ") gg_fail(\"limited array capacity exceeded\"); r.len = s.len; if (s.len) memcpy(r.e, s.data, (size_t)s.len * sizeof(r.e[0])); return r; }\n"));
        }
        if t.size_class != 1 { continue; }
        emit(ctx, str("static int64_t gg_span_", id, "(uint8_t *p, int64_t n) { uint8_t *q = p; while (n-- > 0) q += gg_size_", id, "(q); return q - p; }\n"));
        if t.kind == T_STRUCT {
            emit(ctx, str("static uint8_t *gg_at_", id, "(uint8_t *p, int k) {\n"));
            var e = t.first; var i = 0;
            while e >= 0 {
                let ft = ctx.fielddefs[ctx.edges[e].value].ty;
                emit(ctx, str("  if (k == ", i, ") return p;\n"));
                if ctx.types[ft].size_class == 1 { emit(ctx, str("  p += gg_size_", ft, "(p);\n")); }
                else { emit(ctx, str("  p += sizeof(", c_type(ctx, ft), ");\n")); }
                i++; e = ctx.edges[e].next;
            }
            emit(ctx, "  return p;\n}\n");
            emit(ctx, str("static int64_t gg_size_", id, "(uint8_t *p) { return gg_at_", id, "(p, ", i, ") - p; }\n"));
        } else if t.kind == T_ENUM {
            // The tag byte, then exactly its variant's payload.
            emit(ctx, str("static int64_t gg_size_", id, "(uint8_t *p) { switch (*p) {"));
            var e = t.first;
            while e >= 0 {
                let vt = ctx.edges[e].value;
                if stored_payload(ctx, vt) {
                    emit(ctx, str(" case ", ctx.types[vt].count, ": return 1 + "));
                    if ctx.types[vt].size_class == 1 { emit(ctx, str("gg_size_", vt, "(p + 1);")); } else { emit(ctx, str("(int64_t)sizeof(", c_type(ctx, vt), ");")); }
                }
                e = ctx.edges[e].next;
            }
            emit(ctx, " } return 1; }\n");
        } else if t.kind == T_VARINT {
            emit(ctx, str("static int64_t gg_size_", id, "(uint8_t *p) { return gg_uleb_size(p); }\n"));
        } else if t.kind == T_ARRAY && t.flags == 2 {
            emit(ctx, str("static int64_t gg_size_", id, "(uint8_t *p) { return 8 + (int64_t)*(uint32_t *)p * (int64_t)", c_element_size(ctx, t.element), "; }\n"));
        } else if t.kind == T_ARRAY {
            emit(ctx, str("static int64_t gg_size_", id, "(uint8_t *p) { int64_t n = gg_len_read(p, ", t.count, "), h = gg_len_size(p, ", t.count, "); "));
            if ctx.types[t.element].size_class == 1 { emit(ctx, str("return h + gg_span_", t.element, "(p + h, n); }\n")); }
            else { emit(ctx, str("return h + n * (int64_t)", c_element_size(ctx, t.element), "; }\n")); }
        }
    }
}
// The overload runs on the data stacks above the rendering function's,
// whose base the rendering builtin leaves in gg_render_base.
fn render_overload(ctx: Compiler&, ty: i64) {
    emit(ctx, str("{ int64_t b = gg_render_base; gg_format_", ty, "(out, value, b); gg_render_base = b; }\n"));
}
// gg_format_<ty> calls the overload under the name it has after duplicate
// specializations merge, so it lives among the functions, as a ref.
fn c_format_wrappers(ctx: Compiler&) {
    for t, id in ctx.types {
        if t.formatter < 0 { continue; }
        let params = ctx.specializations[t.formatter].parameters;
        let value = ctx.nodes[ctx.edges[ctx.edges[ctx.nodes[params].first].next].value].symbol;
        let p = ctx.types[ctx.symbols[value].ty];
        // A resizable value is rendered where it lies, read-only: no stack to grow.
        var argument = "value";
        if p.kind == T_REFERENCE { argument = if ctx.types[p.element].size_class == 2 { "gg_ref(&value, NULL)" } else { "&value" }; }
        emit(ctx, str("static void gg_format_", id, "(gg_reference out, ", c_type(ctx, id), " value, int64_t base) { "));
        emit_ref(ctx, "gg_function_", t.formatter); emit(ctx, str("(out, ", argument, ", base); }\n"));
    }
}
fn c_format_helpers(ctx: Compiler&) {
    emit(ctx, "static int64_t gg_render_base;\n");
    c_layout_helpers(ctx);
    emit(ctx, "static void gg_quote(gg_reference out,gg_slice text) { int64_t i; unsigned char c; gg_append(out,\"\\\"\",1,1); for(i=0;i<text.len;i++){c=((unsigned char*)text.data)[i]; if(c=='\\\"'||c=='\\\\'){gg_append(out,\"\\\\\",1,1);gg_append(out,&c,1,1);} else if(c=='\\n')gg_append(out,\"\\\\n\",2,1);else if(c=='\\r')gg_append(out,\"\\\\r\",2,1);else if(c=='\\t')gg_append(out,\"\\\\t\",2,1);else gg_append(out,&c,1,1);}gg_append(out,\"\\\"\",1,1);}\n");
    for t, id in ctx.types {
        if t.kind == T_VOID || t.kind == T_BOTTOM || t.kind == T_NULL || (t.kind == T_ENUM && t.flags & 1 == 0 && !t.fixed_ok) { continue; }
        emit(ctx, str("static uint8_t gg_eq_", id, "(", c_type(ctx, id), " a, ", c_type(ctx, id), " b);\n"));
        emit(ctx, str("static uint8_t gg_equal_elements_", id, "(gg_slice a, gg_slice b);\n"));
        emit(ctx, str("static void gg_render_", id, "(gg_reference out, ", c_type(ctx, id), " value);\n"));
        if t.formatter >= 0 { emit(ctx, str("static void gg_format_", id, "(gg_reference out, ", c_type(ctx, id), " value, int64_t base);\n")); }
        if is_variant(ctx, id) && ctx.types[t.element].fixed_ok {
            let owner = c_type(ctx, t.element);
            emit(ctx, str("static ", owner, " gg_wrap_", id, "(", c_type(ctx, id), " v) { ", owner, " e; memset(&e, 0, sizeof(e)); e.tag = ", t.count, ";"));
            if has_payload(ctx, id) { emit(ctx, str(" e.u.v", t.count, " = v;")); } else { emit(ctx, " (void)v;"); }
            emit(ctx, " return e; }\n");
        }
        // A variable-mode value read into the fixed mode copies its payload out.
        if t.kind == T_ENUM && t.flags & 1 != 0 && ctx.types[t.element].fixed_ok {
            let fixed = c_type(ctx, t.element);
            emit(ctx, str("static ", fixed, " gg_fix_", id, "(uint8_t *p) { ", fixed, " e; memset(&e, 0, sizeof(e)); e.tag = *p; switch (e.tag) {"));
            var e = t.first;
            while e >= 0 {
                let k = ctx.types[ctx.edges[e].value].count;
                if stored_payload(ctx, ctx.edges[e].value) { emit(ctx, str(" case ", k, ": memcpy(&e.u.v", k, ", p + 1, sizeof(e.u.v", k, ")); break;")); }
                e = ctx.edges[e].next;
            }
            emit(ctx, " } return e; }\n");
        }
    }
}
// Bodies follow the function prototypes, since an overload renders a type.
fn c_format_bodies(ctx: Compiler&) {
    for t, id in ctx.types {
        if t.kind == T_VOID || t.kind == T_BOTTOM || t.kind == T_NULL || (t.kind == T_ENUM && t.flags & 1 == 0 && !t.fixed_ok) { continue; }
        if t.size_class == 1 {
            // Variable-size elements sit back to back: walk them pairwise.
            emit(ctx, str("static uint8_t gg_equal_elements_", id, "(gg_slice a,gg_slice b) {int64_t i; uint8_t *p=a.data,*q=b.data; if(a.len!=b.len)return 0;for(i=0;i<a.len;i++){if(!gg_eq_", id, "(p,q))return 0;p+=gg_size_", id, "(p);q+=gg_size_", id, "(q);}return 1;}\n"));
        } else {
            emit(ctx, str("static uint8_t gg_equal_elements_", id, "(gg_slice a,gg_slice b) {int64_t i; if(a.len!=b.len)return 0;for(i=0;i<a.len;i++)if(!gg_eq_", id, "(((", c_type(ctx, id), "*)a.data)[i],((", c_type(ctx, id), "*)b.data)[i]))return 0;return 1;}\n"));
        }
        emit(ctx, str("static uint8_t gg_eq_", id, "(", c_type(ctx, id), " a, ", c_type(ctx, id), " b) {\n"));
        if t.kind == T_STRUCT {
            var e = t.first;
            while e >= 0 {
                let f = ctx.edges[e].value; let ft = ctx.fielddefs[f].ty;
                let left = c_field(ctx, id, "a", f).code; let right = c_field(ctx, id, "b", f).code;
                if ctx.types[ft].kind == T_SLICE { emit(ctx, str("if((", left, ").data!=(", right, ").data || (", left, ").len!=(", right, ").len)return 0;\n")); }
                else { emit(ctx, str("if(!gg_eq_", ft, "(", left, ",", right, "))return 0;\n")); }
                e = ctx.edges[e].next;
            }
            emit(ctx, "return 1;\n");
        } else if t.kind == T_ENUM {
            let a = CValue { code: "a", ty: id }; let b = CValue { code: "b", ty: id };
            emit(ctx, str("if(", c_tag(ctx, a), "!=", c_tag(ctx, b), ")return 0;\nswitch(", c_tag(ctx, a), "){\n"));
            var e = t.first;
            while e >= 0 {
                let vt = ctx.edges[e].value;
                if has_payload(ctx, vt) { emit(ctx, str("case ", ctx.types[vt].count, ": return gg_eq_", vt, "(", c_payload(ctx, a, vt, false), ",", c_payload(ctx, b, vt, false), ");\n")); }
                e = ctx.edges[e].next;
            }
            emit(ctx, "}\nreturn 1;\n");
        } else if t.kind == T_ARRAY || t.kind == T_SLICE {
            emit(ctx, str("return gg_equal_elements_", t.element, "(", c_view(ctx, CValue { code: "a", ty: id }), ",", c_view(ctx, CValue { code: "b", ty: id }), ");\n"));
        } else if t.kind == T_VARINT { emit(ctx, "return gg_zig_read(a) == gg_zig_read(b);\n"); }
        else if t.kind == T_REFERENCE && ctx.types[t.element].size_class == 2 { emit(ctx, "return a.header == b.header;\n"); }
        else { emit(ctx, "return a == b;\n"); }
        emit(ctx, "}\n");
        emit(ctx, str("static void gg_render_", id, "(gg_reference out, ", c_type(ctx, id), " value) {\n"));
        if t.formatter >= 0 { render_overload(ctx, id); }
        else if t.kind == T_INTEGER { emit(ctx, str(if t.flags & 2 != 0 { "gg_unsigned" } else { "gg_integer" }, "(out,value);\n")); }
        else if t.kind == T_FLOAT { emit(ctx, if t.bytes == 4 { "gg_float(out,value,1);\n" } else { "gg_float(out,value,0);\n" }); }
        else if t.kind == T_BOOL { emit(ctx, "gg_bool(out,value);\n"); }
        else if t.kind == T_VARINT { emit(ctx, "gg_integer(out,gg_zig_read(value));\n"); }
        else if t.kind == T_REFERENCE {
            var target = "*value";
            if ctx.types[t.element].size_class == 2 { target = "*value.header"; }
            if ctx.types[t.element].size_class == 1 { target = "value"; }
            if t.flags & 4 != 0 { emit(ctx, str("if (!", c_present(ctx, CValue { code: "value", ty: id }), ") { gg_append(out,\"null\",4,1); return; }\n")); }
            emit(ctx, str("gg_render_", t.element, "(out,", target, ");\n"));
        } else if t.kind == T_ENUM {
            let value = CValue { code: "value", ty: id };
            emit(ctx, str("switch(", c_tag(ctx, value), "){\n"));
            var e = t.first;
            while e >= 0 {
                let vt = ctx.edges[e].value;
                emit(ctx, str("case ", ctx.types[vt].count, ": "));
                if stored_payload(ctx, vt) { emit(ctx, str("gg_render_", vt, "(out,", c_payload(ctx, value, vt, false), ");")); }
                else { render_constant(ctx, vt); }
                emit(ctx, " break;\n"); e = ctx.edges[e].next;
            }
            emit(ctx, "}\n");
        } else if is_variant(ctx, id) && !stored_payload(ctx, id) { render_constant(ctx, id); emit(ctx, "\n"); }
        else if t.kind == T_STRUCT {
            let name = ctx.tokens[ctx.nodes[t.decl].token].text;
            let prefix = save_text(ctx, str(name, " { "));
            emit(ctx, str("gg_append(out,", c_literal(ctx, prefix), ",", prefix.len, ",1);\n"));
            var e = t.first; var first = true;
            while e >= 0 {
                let f = ctx.edges[e].value;
                if !first { emit(ctx, "gg_append(out,\", \",2,1);\n"); } first = false;
                render_field(ctx, ctx.fielddefs[f].ty, c_field(ctx, id, "value", f).code); emit(ctx, "\n"); e = ctx.edges[e].next;
            }
            emit(ctx, "gg_append(out,\" }\",2,1);\n");
        } else if t.kind == T_ARRAY || t.kind == T_SLICE {
            let view = c_view(ctx, CValue { code: "value", ty: id });
            if t.element == integer_type(ctx, 1, true) { emit(ctx, str("gg_text(out,", view, ");\n")); }
            else if ctx.types[t.element].size_class == 1 {
                emit(ctx, str("int64_t i; gg_slice view=", view, "; uint8_t *p=view.data; gg_append(out,\"[\",1,1);for(i=0;i<view.len;i++){if(i)gg_append(out,\", \",2,1);"));
                render_field(ctx, t.element, "p");
                emit(ctx, str("p+=gg_size_", t.element, "(p);}gg_append(out,\"]\",1,1);\n"));
            } else {
                emit(ctx, str("int64_t i; gg_slice view=", view, ";gg_append(out,\"[\",1,1);for(i=0;i<view.len;i++){if(i)gg_append(out,\", \",2,1);"));
                render_field(ctx, t.element, save_text(ctx, str("((", c_type(ctx, t.element), "*)view.data)[i]")));
                emit(ctx, "}gg_append(out,\"]\",1,1);\n");
            }
        }
        emit(ctx, "}\n");
    }
}

// One compilation owns each table locally. The fixed-size context borrows
// those tables so recursive passes can share them without global state.
struct CValue {
    code: const u8[:],
    ty: i64,
    address: const u8[:] = "",
    stack: const u8[:] = "",
}
// A break with a value fills the control's destination, parked as offsets into
// the text arena: a view may not be stored inside the emitter's recursive cycle.
struct Control { again: i64, done: i64, ty: i64 = 0, code: i64 = 0, address: i64 = 0, stack: i64 = 0, code_len: i64 = 0, address_len: i64 = 0, stack_len: i64 = 0 }
struct FunctionInstance { template: i64, arguments: i64, symbol: i64 }

struct Compiler {
    function_instances: FunctionInstance[>..]&,
    checked_calls: CheckedCall[>..]&,
    shrinks: Shrink[>..]&,
    effect_revision: i64 = 0,
    flow: i64 = -1,
    visit: i64 = 0,
    specializations: Specialization[>..]&,
    checking_function: i64 = -1,
    // While a parameter default is checked, lookups that reach its call-site
    // scope continue in the declaration's scope instead (§7.1).
    default_floor: i64 = -1,
    default_scope: i64 = -1,
    default_limit: i64 = -1,
    default_decl: i64 = -1,
    default_param: i64 = -1,
    // The token of the call whose default is being checked, for src_line.
    default_site: i64 = -1,
    loop_depth: i64 = 0,
    // Breaks seen in the innermost loop or block being checked.
    loop_breaks: i64 = 0,
    break_target: i64 = -1,
    // While a defer body is checked, the loop depth around it: no exit in
    // the body may leave it (6.6).
    defer_loops: i64 = -1,
    global_order: i64[>..]&,
    c_output: u8[>..]&,
    c_declarations: u8[>..]&,
    c_temporary: i64 = 0,
    c_function: i64 = -1,
    c_slots: i64 = 0,
    c_global_slots: i64 = 0,
    symbol_slots: i64[>..]&,
    c_type_state: i64[>..]&,
    function_slots: i64[>..]&,
    return_locals: i64[>..]&,
    c_final: u8[>..]&,
    c_specs: u8[>..]&,
    c_spec_start: i64[>..]&,
    c_spec_split: i64[>..]&,
    local_names: i64[>..]&,
    first_local: i64[>..]&,
    next_local: i64[>..]&,
    c_controls: Control[>..<]&,
    // Defers in scope while emitting: again is the defer node, done the
    // count of controls around it, so a break knows which it leaves.
    c_defers: Control[>..<]&,
    c_arguments: (const u8[:])[>..<]&,
    // (call node, number) for this function's multiple-result calls.
    c_multis: i64[>..<]&,
    // Parameter tokens of the defaults being checked, innermost last. A -1
    // separates those of a function body being checked from its callers'.
    default_stack: i64[>..<]&,
    c_label: i64 = 0,
    c_result: CValue = CValue { code: "", ty: 0 },
    text_storage: u8[>..]&,
    sources: Source[>..]&,
    tokens: Token[>..]&,
    nodes: Node[>..]&,
    edges: Edge[>..]&,
    declarations: i64[>..]&,
    current_namespace: i64 = -1,
    cursor: i64 = 0,
    parse_limit: i64 = 0,
    parse_depth: i64 = 0,
    instantiation_depth: i64 = 0,
    formatters: i64 = 0,
    types: Type[>..]&,
    fielddefs: Field[>..]&,
    scopes: Scope[>..]&,
    symbols: Symbol[>..]&,
    symbol_buckets: i64[>..]&,
    symbol_chain: i64[>..]&,
    call_start: i64[>..]&,
    call_targets: i64[>..]&,
    cycle_stack: i64[>..]&,
    cycle_counter: i64 = 0,
    cycle_top: i64 = 0,
}

fn run_compilation(mode: i64, path: const u8[:], output: const u8[:]) {
    var owned_function_instances: FunctionInstance[>..] = [];
    var owned_checked_calls: CheckedCall[>..] = [];
    var owned_shrinks: Shrink[>..] = [];
    var owned_specializations: Specialization[>..] = [];
    var owned_global_order: i64[>..] = [];
    var owned_c_output: u8[>..] = [];
    var owned_c_declarations: u8[>..] = [];
    var owned_symbol_slots: i64[>..] = [];
    var owned_c_type_state: i64[>..] = [];
    var owned_function_slots: i64[>..] = [];
    var owned_return_locals: i64[>..] = [];
    var owned_c_final: u8[>..] = [];
    var owned_default_stack: i64[>..<] = [];
    var owned_c_specs: u8[>..] = [];
    var owned_c_spec_start: i64[>..] = [];
    var owned_c_spec_split: i64[>..] = [];
    var owned_local_names: i64[>..] = [];
    var owned_first_local: i64[>..] = [];
    var owned_next_local: i64[>..] = [];
    var owned_c_controls: Control[>..<] = [];
    var owned_c_defers: Control[>..<] = [];
    var owned_c_arguments: (const u8[:])[>..<] = [];
    var owned_c_multis: i64[>..<] = [];
    var owned_text_storage: u8[>..] = [];
    var owned_sources: Source[>..] = [];
    var owned_tokens: Token[>..] = [];
    var owned_nodes: Node[>..] = [];
    var owned_edges: Edge[>..] = [];
    var owned_declarations: i64[>..] = [];
    var owned_types: Type[>..] = [];
    var owned_fielddefs: Field[>..] = [];
    var owned_scopes: Scope[>..] = [];
    var owned_symbols: Symbol[>..] = [];
    var owned_symbol_buckets: i64[>..] = [];
    var owned_symbol_chain: i64[>..] = [];
    var owned_call_start: i64[>..] = [];
    var owned_call_targets: i64[>..] = [];
    var owned_cycle_stack: i64[>..] = [];
    var ctx = Compiler {
        function_instances: owned_function_instances,
        checked_calls: owned_checked_calls,
        shrinks: owned_shrinks,
        specializations: owned_specializations,
        global_order: owned_global_order,
        c_output: owned_c_output,
        c_declarations: owned_c_declarations,
        symbol_slots: owned_symbol_slots,
        c_type_state: owned_c_type_state,
        function_slots: owned_function_slots,
        return_locals: owned_return_locals,
        c_final: owned_c_final,
        c_specs: owned_c_specs,
        c_spec_start: owned_c_spec_start,
        c_spec_split: owned_c_spec_split,
        local_names: owned_local_names,
        first_local: owned_first_local,
        next_local: owned_next_local,
        c_controls: owned_c_controls,
        c_defers: owned_c_defers,
        c_arguments: owned_c_arguments,
        c_multis: owned_c_multis,
        default_stack: owned_default_stack,
        text_storage: owned_text_storage,
        sources: owned_sources,
        tokens: owned_tokens,
        nodes: owned_nodes,
        edges: owned_edges,
        declarations: owned_declarations,
        types: owned_types,
        fielddefs: owned_fielddefs,
        scopes: owned_scopes,
        symbols: owned_symbols,
        symbol_buckets: owned_symbol_buckets,
        symbol_chain: owned_symbol_chain,
        call_start: owned_call_start,
        call_targets: owned_call_targets,
        cycle_stack: owned_cycle_stack,
    };
    compile_command(ctx, mode, path, output);
}

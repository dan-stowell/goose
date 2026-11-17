reusable var pool: i64[>..] = [11, 22, 33];
fn release(p: i64[>..]&, i: i64) { p.free(i); }
struct Cell { n: i64 }
reusable var cells: Cell[>..] = [Cell { 1 }];
fn free_cell() -> i64 { cells.free(0); return 42; }
fn main() {
    pool.free(0);
    release(pool, 2);
    assert(pool.len == 3 && pool[0] == 11);
    assert(pool.alloc_index(44) == 2);
    let r .= pool.alloc_ref(55);
    assert(pool.index_of(r) == 0 && r == 55);
    assert(alloc_index(pool, 66) == 3 && pool.len == 4);
    free(pool, 1);
    assert(pool.alloc_index(77) == 1);
    for i in 3 {
        reusable var local: i64[>..] = [1, 2];
        local.free(1);
        assert(local.alloc_index(3) == 1);
        local.free(1);
    }
    let new_slot = cells.alloc_index(Cell { free_cell() });
    assert(new_slot == 0 && cells.len == 1);
    assert(cells.alloc_index(Cell { 99 }) == 1);
    var duplicate = copy(pool);
    assert(duplicate.len == pool.len);
    print("slot builtins: ok");
}

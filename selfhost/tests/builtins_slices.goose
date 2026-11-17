var defaults = 0;
fn next() -> i64 { defaults++; return defaults; }
struct Cell { value: i64 = next() }
fn main() {
    reusable[] var pool: i64[>..] = [];
    var a = pool.alloc_slice(3);
    var b = alloc_slice(pool, 3);
    assert(a == [0, 0, 0] && pool.range_index(b) == 3);
    a[0] = 11; a[1] = 22;
    free_slice(pool, a);
    var c = pool.alloc_slice(2);
    assert(pool.range_index(c) == 0 && c == [0, 0]);
    c[0] = 7; c[1] = 8;
    pool.free_slice(b);
    c = pool.realloc_slice(c, 5);
    assert(pool.range_index(c) == 0 && c == [7, 8, 0, 0, 0]);
    assert(pool.range_index(pool.alloc_slice(1)) == 5);
    pool.free_slice(default<i64[:]>());
    assert(pool.alloc_slice(0).len == 0);
    reusable[] var overlap: i64[>..] = [];
    let left = overlap.alloc_slice(2);
    var middle = overlap.alloc_slice(2);
    let right = overlap.alloc_slice(2);
    middle[0] = 91; middle[1] = 92;
    overlap.free_slice(left);
    middle = realloc_slice(overlap, middle, 4);
    assert(overlap.range_index(middle) == 0 && middle == [91, 92, 0, 0]);
    assert(overlap.range_index(right) == 4);
    reusable[] var cells: Cell[>..] = [];
    var cs = cells.alloc_slice(3);
    assert(defaults == 3 && cs[0].value == 1 && cs[2].value == 3);
    cs = cells.realloc_slice(cs, 5);
    assert(defaults == 5 && cs[4].value == 5);
    cs = cells.realloc_slice(cs, 2);
    assert(defaults == 5 && cells.len == 5);
    reusable[] var nested: Cell[2][>..] = [];
    let ns = nested.alloc_slice(2);
    assert(defaults == 9 && ns[0][0].value == 6 && ns[1][1].value == 9);
    print("slice pool builtins: ok");
}

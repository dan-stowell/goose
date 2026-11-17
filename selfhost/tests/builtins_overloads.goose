fn free(x: i64) { print(x); }
fn bytes_of(x: i64) -> i64 { x + 1 }
fn main() {
    free(7);
    assert(bytes_of(8) == 9);
    reusable var p: i64[>..] = [1, 2];
    free(p, 1);
    assert(p.alloc_index(3) == 1);
    p.free(0);
    assert(p.alloc_index(4) == 0);
    assert(bytes_of(p).len == 16);
    assert(p.bytes_of().len == 16);
    print("overload builtins: ok");
}

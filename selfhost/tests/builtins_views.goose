var first: i64[4] = [1, 2, 3, 4];
var second: i64[4] = [5, 6, 7, 8];
var target: i64[:] = first[..];
fn source() -> i64[:] { target = second[..]; return second[..]; }
struct Pair { x: u16, y: u8 }
fn main() {
    var a = [1, 2, 3, 4, 5];
    a[1..].move_from(a[..4]);
    assert(a == [1, 1, 2, 3, 4]);
    move_from(a[..4], a[1..]);
    assert(a == [1, 2, 3, 4, 4]);
    a[..0].move_from(default<i64[:]>());
    target.move_from(source());
    assert(first == second);
    assert(a.index_of(a[3]) == 3);
    let r .= a[1];
    assert(index_of(a, r) == 1);
    var words: u16[2] = [258, 772];
    let bytes = bytes_of(words);
    assert(bytes.len == 4 && bytes[0] == 2 && bytes[1] == 1 && bytes[2] == 4);
    words[0] = 513;
    assert(bytes[0] == 1 && bytes[1] == 2);
    var pairs = [Pair { 258, 3 }, Pair { 1029, 6 }];
    assert(pairs.bytes_of().len == 6 && pairs.bytes_of()[2] == 3);
    print("view builtins: ok");
}

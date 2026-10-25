// Multiple results adapt independently, while a value context takes only the
// first. A receiver runs the call before evaluating and storing its targets.
var calls = 0;
fn small() -> u8, i16, f32 {
    calls += 1;
    return 7, -9, 1.5;
}
fn wide() -> i64, i32, f64 { return small(); }
fn inferred() { return 3, 4; }
recursive fn forwarded(n: i64) -> i64, i64 {
    if n == 0 { return inferred(); }
    return forwarded(n - 1);
}
fn redirect(index: i64&) -> i64, i64 {
    index = 1;
    return 0, 42;
}
struct Pair { x: i64, y: i64 }
fn aggregate() -> i64[2], Pair {
    return [5, 6], Pair { x: 8, y: 9 };
}
fn refs(a: i64&, b: i64&) -> i64&, i64& { return a, b; }
fn copied(a: i64&, b: i64&) -> i64, i64 { return refs(a, b); }
fn views(xs: i64[:]) -> i64[:], i64[:] { return xs[..1], xs[1..]; }
fn take(n: i64) -> i64 { return n + 1; }
fn main() {
    let a, b, c = wide();
    print(a, " ", b, " ", c);
    var d, e, f = small();
    d = 10; e = -20; f = 2.5;
    print(d, " ", e, " ", f);
    let first = small();
    print(first + 1, " ", take(small()));
    small();
    print(calls);
    let p, q = forwarded(2);
    print(p, " ", q);
    var index = 2;
    var xs = [10, 20, 30];
    index, xs[index] = redirect(index);
    print(index, " ", xs);
    index, index = inferred();
    print(index);
    let numbers, record = aggregate();
    print(numbers, " ", record.x, " ", record.y);
    var left = 11;
    var right = 12;
    let l, r = refs(left, right);
    let lc, rc = copied(left, right);
    left = 21; right = 22;
    print(l, " ", r, " ", lc, " ", rc);
    let head, tail = views(xs);
    head[0] = 99; tail[0] = 88;
    print(xs);
}

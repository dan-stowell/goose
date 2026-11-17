// Evaluation order the emitter must keep when it drops temporaries. Expected output (stock goose):
// 12 1121 15 1020 16 5 8 11 false 10
fn bump(x: i64&) -> i64 { x += 10; return x; }
fn pair(a: i64, b: i64) -> i64 { return a * 100 + b; }
fn grow(xs: i64[>..]&) -> i64 { xs.push(7); return xs.len; }
fn main() {
    var x = 1;
    let a = x + bump(x);
    let b = pair(x, bump(x));
    var y = 5;
    fn inner() -> i64 { y = y * 2; return y; }
    let c = y + inner();
    let d = pair(y, inner());
    var z = 3;
    z += bump(z);
    var xs: i64[>..] = [];
    xs.push(1); xs.push(2);
    let e = xs.len + grow(xs);
    let f = xs[0] + xs[xs.len - 1];
    var i = 0;
    let g = xs[i] + pair(i, bump(i));
    let h = !(x > 3) && y < 100 || z == 0;
    print(a, " ", b, " ", c, " ", d, " ", z, " ", e, " ", f, " ", g, " ", h, " ", i);
}

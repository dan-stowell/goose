// error: 3 targets need that many values, and the call gives 2
fn pair() -> i64, i64 { return 1, 2; }
fn main() {
    var a = 0;
    var b = 0;
    var c = 0;
    a, b, c = pair();
}

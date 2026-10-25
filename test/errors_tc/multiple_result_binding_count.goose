// error: 3 names need that many values, and the call gives 2
fn pair() -> i64, i64 { return 1, 2; }
fn main() {
    let a, b, c = pair();
    print(a, b, c);
}

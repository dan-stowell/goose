// error: returning 2 value(s), function single has 1
fn pair() -> i64, i64 { return 1, 2; }
fn single() -> i64 { return pair(); }
fn main() { print(single()); }

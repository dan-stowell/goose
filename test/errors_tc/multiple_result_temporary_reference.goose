// error: returning a reference into a temporary
fn arrays() -> i64[2], i64[2] { return [1, 2], [3, 4]; }
fn slices() -> const i64[:], const i64[:] { return arrays(); }
fn main() { let a, b = slices(); print(a, b); }

// error: call into a recursive cycle while nonfixed local is in scope
// Selfhost-only fixture: the checker's cycle test (strongly connected components).
recursive fn even(n: i64) -> bool { var xs: i64[>..] = []; xs.push(n); if n == 0 { return true; } return odd(n - 1); }
recursive fn odd(n: i64) -> bool { if n == 0 { return false; } return even(n - 1); }
fn leaf(n: i64) -> i64 { return n + 1; }
fn main() { var ys: i64[>..] = []; ys.push(leaf(1)); print(even(4)); }

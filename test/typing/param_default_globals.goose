// Parameter defaults taken by calls in global initializers (§7.1, §11.1). The
// default is evaluated at the call, so a block default's locals, a nonfixed
// one among them, live while the initializer runs, before main has a frame;
// blocks written in the initializer itself keep their locals the same way.

let base = 5;
fn twice(x: i64) -> i64 { x * 2 }
fn plain(x: i64 = { let t = 2; t }) -> i64 { x }
fn scaled(x: i64 = { let t = twice(base); t + 1 }) -> i64 { x }
fn summed(a: i64, b: i64 = { var acc = 0; for i in 0..base { acc += i; } acc }) -> i64 { a + b }
fn nested(n: i64 = scaled()) -> i64 { n * 10 }
fn counted(n: i64 = { let w: u8[>..] = [1, 2, 3]; w.len }) -> i64 { n }

let value = plain();
let written = scaled(3);
let defaulted = scaled();
let sum = summed(4);
let chained = nested();
let grouped = { let inner = summed(2); inner + scaled() };
let branch = if value > 0 { let q = counted(); q * 2 } else { 0 };

fn main() {
    print(value);
    print(written);
    print(defaulted);
    print(sum);
    print(chained);
    print(grouped);
    print(branch);
    // The same defaults taken from a function body, for comparison.
    print(plain());
    print(summed(4));
    print(counted());
}

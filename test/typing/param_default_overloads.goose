// Parameter defaults beside overloading (§7.1). A default is no argument: a
// candidate the call leaves parameters of to their defaults ranks by the
// written arguments alone, and only the chosen one's defaults are then
// checked and evaluated, after the written arguments, in parameter order.

var trace: i64[>..] = [];
var counter = 0;

fn note(v: i64) -> i64 { trace.push(v); v }
fn bump() -> i64 { counter += 1; counter }

// The concrete exact match wins over one needing a literal fit or a
// widening, whether or not it leaves a default out.
fn rank(a: i64, b: i64 = 10) -> i64 { a + b }
fn rank(a: i32) -> i64 { a * 2 }
// Arity decides too: three written arguments rule out both of the above.
fn rank(a: i64, b: i64, c: i64, d: i64 = note(40)) -> i64 { a + b + c + d }
// A generic candidate ranks below a concrete exact one, by its written
// arguments only, and its default takes the type it binds.
fn same<T>(a: T, b: T, c: i64 = note(30)) -> i64 { c }
fn same(a: i64, b: i64) -> i64 { a * b }

// Defaults run after every written argument, in parameter order, and see
// what the written ones did.
fn order(a: i64, b: i64 = note(2), c: i64 = note(3)) -> i64 { a * 100 + b * 10 + c }
fn after(a: i64, b: i64 = counter) -> i64 { a * 10 + b }

fn main() {
    let n: i64 = 4;
    let m: i32 = 5;
    print(rank(n), " ", rank(m), " ", rank(1), " ", rank(1, 2), " ", rank(1, 2, 3));
    print(same(3, 4), " ", same(true, false), " ", same(m, m, 7));
    print(trace);
    trace.clear();
    print(order(note(1)), " ", order(note(4), note(5)));
    print(trace);
    print(after(bump()), " ", after(bump()), " ", after(1, bump()));
    print(n.rank(), " ", m.rank(), " ", 2.order());
}

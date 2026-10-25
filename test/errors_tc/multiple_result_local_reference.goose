// error: returning a reference rooted in local
fn dangling(a: i64&) -> i64&, i64& {
    var local = 2;
    return a, local;
}
fn main() {
    var x = 1;
    let a, b = dangling(x);
    print(a, b);
}

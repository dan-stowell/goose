// Differential runtime coverage: both call forms, overlap boundaries and counts.
var values: i64[>..<] = [10, 20, 30, 40];
fn main() {
    assert(values.check_length(7) == 7);
    assert(check_length(values, 0) == 0);
    assert(values.len == 4);
    assert(values.range_index(values[1..3]) == 1);
    var foreign = [1, 2];
    assert(values.range_index(foreign[..0]) == 0);
    assert(range_index(foreign, foreign[1..]) == 1);
    values.pop_n(2);
    assert(values.len == 2);
    pop_n(values, 0);
    values.push(50);
    assert(values[2] == 50);
    pop_n(values, values.len);
    assert(values.len == 0);
    print("count builtins: ok");
}

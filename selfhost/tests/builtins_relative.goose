struct Node { n: i64, next: Node&<u32>? }
var values: i64[>..] = [11, 22];
reusable var refs: (i64&<u32 in values>)[>..] = [];
fn main() {
    reusable var nodes: Node[>..] = [];
    let first .= nodes.alloc_ref(Node { 7, null });
    let second .= nodes.alloc_ref(Node { 9, first });
    let prev = second.next; assert(prev); assert(prev.n == 7);
    assert(bytes_of(nodes).len == 24);
    nodes.free(1);
    let third .= nodes.alloc_ref(Node { 13, first });
    let prev2 = third.next; assert(prev2); assert(prev2.n == 7);
    let value .= refs.alloc_ref(values[1]);
    assert(value == 22);
    refs.free(0);
    let again .= refs.alloc_ref(values[0]);
    assert(again == 11);
    print("relative pool builtins: ok");
}

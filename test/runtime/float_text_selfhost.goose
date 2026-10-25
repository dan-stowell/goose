// runtime-debug: float text at both widths, through every formatting path
// the self-hosted compiler supports (§3.7). Array loads keep the arithmetic
// and formatting at run time. Powers of ten pin down the notation boundaries.
struct FloatPair { wide: f64, narrow: f32 }

fn main() {
    var powers: f64[>..] = [1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3,
        1e-2, 1e-1, 1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9,
        1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19,
        1e20, 1e21, 1e22, 1e23, 1e24, 1e25];
    var powers32: f32[>..] = [1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3,
        1e-2, 1e-1, 1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9,
        1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19,
        1e20, 1e21, 1e22, 1e23, 1e24, 1e25];
    for x, i in powers { print(i - 10, " ", x, " ", powers32[i]); }

    var wide: f64[>..] = [0.0, 1.0, 2.0, 0.1, 5e-324, 1e-310,
        2.2250738585072014e-308, 1.7976931348623157e308,
        1.23456789012345, 1.234567890123456, 1.2345678901234567,
        1234567890123456.0, 12345678901234560.0, 12345678901234568.0,
        123456789012345680.0, 999999999999999.9, 0.30000000000000004];
    var narrow: f32[>..] = [0.0, 1.0, 2.0, 0.1, 1e-45, 1e-40,
        1.17549435e-38, 3.4028235e38, 2147483648.0, 0.33333334, 1.0000001];
    for x in wide { print(x, " ", -x); }
    for x in narrow { print(x, " ", -x); }
    print(narrow[3] as f64, " ", wide[3] as f32);
    print(str(wide[2], " ", narrow[3], " ", -narrow[0]));
    var text: u8[>..] = [];
    format(text, wide[4], " ", narrow[7], " ", wide[11]);
    print(text);
    print(FloatPair { wide[2], narrow[3] });
    print(wide[0..5], " ", narrow[0..5]);
    let ref: f32& = narrow[3];
    print(ref);

    let inf = wide[1] / wide[0];
    let nan = wide[0] / wide[0];
    let inf32 = narrow[1] / narrow[0];
    let nan32 = narrow[0] / narrow[0];
    print(inf, " ", -inf, " ", nan, " ", -nan);
    print(inf32, " ", -inf32, " ", nan32, " ", -nan32);
    print(str(inf, " ", -inf32, " ", -nan, " ", nan32));
    text.clear();
    format(text, -inf, " ", inf32, " ", nan, " ", -nan32);
    print(text);
    print([inf, -inf, nan, -nan]);
    print([inf32, -inf32, nan32, -nan32]);
    print(FloatPair { -nan, -inf32 });
}

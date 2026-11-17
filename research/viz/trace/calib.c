/* Calibration for the cache model: random 8-byte reads over a working set
   of SIZE bytes (argv[1]), N reads (argv[2]). Under bytemove nearly all
   reads should come from the level whose capacity first holds SIZE:
   16 KB -> L1, 512 KB -> L2, 8 MB -> L3, 256 MB -> memory. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
int main(int argc, char **argv) {
    size_t size = strtoull(argv[1], 0, 10), n = strtoull(argv[2], 0, 10), words = size / 8;
    uint64_t *a = malloc(size), x = 88172645463325252ull, sum = 0;
    for (size_t i = 0; i < words; i++) a[i] = i;          /* warm: touch every line */
    for (size_t i = 0; i < words; i++) sum += a[i];
    for (size_t i = 0; i < n; i++) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; sum += a[x % words]; }
    printf("%llu\n", (unsigned long long)sum);
    return 0;
}

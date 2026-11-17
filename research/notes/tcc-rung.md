# Self-hosted rung through TinyCC (2026-11-17, lead)

build/tcc/tcc (built by cmake/libtcc.cmake) works as a CLI with
`tcc -B build/tcclib -I/usr/include/x86_64-linux-gnu -I/usr/include -c x.c` and a gcc link
(`gcc -Wl,--no-eh-frame-hdr -z noexecstack x.o build/tcclib/libtcc1.a -lm`; tcc's own link can't find crt1.o
because the build's CONFIG_TCC_LIBPATHS is {B} only).

- tcc -c sh2.c (3.66 MB): 0.06-0.07 s, 12 MB peak; deduped sh2d.c (1.59 MB): 0.02-0.04 s.
- The tcc-built stage 2 holds the fixed point (identical C), but runs W1 in 5.86-5.91 s against
  0.32-0.34 s for the gcc -O2 build: 18x. The emitted C leans on gcc to remove its temporaries,
  frame-struct traffic and gg_view/gg_index helper calls. Implication for M3: on the fast path
  the C we emit must be good C before any optimizer sees it (or we emit machine code ourselves).

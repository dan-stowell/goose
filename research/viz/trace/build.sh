#!/bin/sh
# Builds the bytemove Valgrind tool against the installed valgrind (3.22,
# Ubuntu 24.04 ships its headers and static core libraries) and lays out a
# VALGRIND_LIB directory holding it beside the stock tools' support files.
# Usage: build.sh OUTDIR   then   VALGRIND_LIB=OUTDIR valgrind --tool=bytemove ...
set -e
here=$(cd "$(dirname "$0")" && pwd)
out=${1:?usage: build.sh OUTDIR}
lib=/usr/lib/x86_64-linux-gnu/valgrind
mkdir -p "$out"
gcc -m64 -O2 -g -std=gnu99 -I/usr/include/valgrind \
  -DVGA_amd64=1 -DVGO_linux=1 -DVGP_amd64_linux=1 -DVGPV_amd64_linux_vanilla=1 \
  -fno-strict-aliasing -fno-builtin -fno-stack-protector -fno-pie -fno-pic \
  -Wall -Wno-unused-function -c "$here/bytemove.c" -o "$out/bytemove.o"
gcc -m64 -o "$out/bytemove-amd64-linux" -static -nodefaultlibs -nostartfiles -u _start \
  -Wl,--build-id=none -Wl,-Ttext-segment=0x58000000 -no-pie \
  "$out/bytemove.o" "$lib/libcoregrind-amd64-linux.a" "$lib/libvex-amd64-linux.a" -lgcc \
  "$lib/libgcc-sup-amd64-linux.a"
for f in /usr/libexec/valgrind/*; do
  b=$(basename "$f"); [ -e "$out/$b" ] || ln -s "$f" "$out/$b"
done
for f in; do
  b=$(basename "$f"); [ -e "$out/$b" ] || ln -s "$f" "$out/$b"
done
echo "built $out/bytemove-amd64-linux"

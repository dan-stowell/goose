#!/usr/bin/env bash
# Reproduce the run's VM setup (Ubuntu 24.04, 2026-11-17): tools, then the C++ compiler with all packages.
set -euo pipefail
cd "$(dirname "$0")/.."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q cmake ninja-build valgrind linux-tools-generic \
  libx11-dev libxext-dev libwayland-dev libxkbcommon-dev wayland-protocols libxcursor-dev libxi-dev \
  libxrandr-dev libxss-dev libxfixes-dev libxtst-dev libasound2-dev libpulse-dev libegl-dev libgl-dev \
  libdrm-dev libgbm-dev libvulkan-dev mesa-vulkan-drivers
# The kernel (6.12) has no matching linux-tools package; the 6.8 perf works against it.
sudo ln -sf "$(ls /usr/lib/linux-tools/*/perf | head -1)" /usr/local/bin/perf
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DGOOSE_BUILTIN_LIBS=all
cmake --build build

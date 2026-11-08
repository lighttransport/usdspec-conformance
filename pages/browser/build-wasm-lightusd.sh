#!/usr/bin/env bash
# Build the LightUSD `next` WASM backend for the browser workbench.
#
# Requires emsdk sourced (e.g. `source $HOME/emsdk/emsdk_env.sh`) and the
# LightUSD checkout at $LIGHTUSD_ROOT (default: $HOME/work/tinyusdz/large-scene).
set -euo pipefail

LIGHTUSD_ROOT="${LIGHTUSD_ROOT:-$HOME/work/tinyusdz/large-scene}"
OUT_DIR="${1:-$PWD/pages/browser/wasm}"
BUILD_DIR="$PWD/build/browser-lightusd-wasm"

mkdir -p "$OUT_DIR" "$BUILD_DIR"
emcmake cmake -DLIGHTUSD_WASM_PRODUCT=next -G Ninja -DCMAKE_BUILD_TYPE=MinSizeRel \
  -B "$BUILD_DIR" "$LIGHTUSD_ROOT/web" >/tmp/opencode/browser-lightusd-cmake.log 2>&1
ninja -C "$BUILD_DIR" >/tmp/opencode/browser-lightusd-ninja.log 2>&1

cp "$BUILD_DIR"/lightusd_next.js "$BUILD_DIR"/lightusd_next.wasm "$OUT_DIR"/ 2>/dev/null || \
  cp "$BUILD_DIR/lightusd_next_build/lightusd_next.js" "$BUILD_DIR/lightusd_next_build/lightusd_next.wasm" "$OUT_DIR"/
sha256sum "$OUT_DIR"/lightusd_next.wasm | awk '{print $1}' > "$OUT_DIR"/lightusd_next.sha256
ls -la "$OUT_DIR"
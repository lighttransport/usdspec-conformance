#!/usr/bin/env bash
# Build the LightUSD `next` WASM backend for the browser workbench.
#
# Usage: pages/browser/build-wasm-lightusd.sh [OUT_DIR]
#   OUT_DIR defaults to pages/browser/wasm (relative to the repo root).
#
# Requires:
#   - emsdk active (`source .../emsdk_env.sh`); CI installs 4.0.14.
#   - LIGHTUSD_ROOT pointing at a LightUSD/TinyUSDZ checkout containing web/.
#
# Produces OUT_DIR/lightusd_next.js, lightusd_next.wasm and lightusd_next.sha256.
# The workbench manifest (`wasm/manifest.json`) references these same filenames.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIGHTUSD_ROOT="${LIGHTUSD_ROOT:?set LIGHTUSD_ROOT to the LightUSD checkout}"
OUT_DIR="${1:-$REPO_ROOT/pages/browser/wasm}"
BUILD_DIR="$REPO_ROOT/build/browser-lightusd-wasm"

[ -f "$LIGHTUSD_ROOT/web/CMakeLists.txt" ] || {
  echo "error: $LIGHTUSD_ROOT/web/CMakeLists.txt not found (wrong LIGHTUSD_ROOT?)" >&2
  exit 1
}

mkdir -p "$OUT_DIR" "$BUILD_DIR"
emcmake cmake -DLIGHTUSD_WASM_PRODUCT=next -G Ninja -DCMAKE_BUILD_TYPE=MinSizeRel \
  -B "$BUILD_DIR" "$LIGHTUSD_ROOT/web"
ninja -C "$BUILD_DIR"

# CMake writes the module next to the source bindings; older layouts use the
# build tree. Accept either.
JS=""
WASM=""
for d in "$LIGHTUSD_ROOT/web/js/src/lightusd" "$BUILD_DIR" "$BUILD_DIR/lightusd_next_build"; do
  if [ -z "$JS" ] && [ -f "$d/lightusd_next.js" ]; then JS="$d/lightusd_next.js"; fi
  if [ -z "$WASM" ] && [ -f "$d/lightusd_next.wasm" ]; then WASM="$d/lightusd_next.wasm"; fi
done
[ -n "$JS" ] && [ -n "$WASM" ] || {
  echo "error: lightusd_next.{js,wasm} not found after build" >&2
  exit 1
}

cp "$JS" "$OUT_DIR/lightusd_next.js"
cp "$WASM" "$OUT_DIR/lightusd_next.wasm"
sha256sum "$OUT_DIR/lightusd_next.wasm" | awk '{print $1}' > "$OUT_DIR/lightusd_next.sha256"
ls -la "$OUT_DIR"
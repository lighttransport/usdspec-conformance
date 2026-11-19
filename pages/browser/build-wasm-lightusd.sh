#!/usr/bin/env bash
# Build the LightUSD `core` WASM backend for the browser workbench.
#
# Usage: pages/browser/build-wasm-lightusd.sh [OUT_DIR]
#   OUT_DIR defaults to pages/browser/wasm (relative to the repo root).
#
# Requires:
#   - emsdk active (`source .../emsdk_env.sh`); CI installs 7.0.0.
#   - LIGHTUSD_ROOT pointing at a LightUSD/TinyUSDZ checkout containing web/.
#
# Produces OUT_DIR/lightusd.js, lightusd.wasm and lightusd.sha256.
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
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
emcmake cmake -S "$LIGHTUSD_ROOT/web" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=MinSizeRel -DLIGHTUSD_WASM_PRODUCT=core -DLIGHTUSD_WASM64=OFF \
  -DLIGHTUSD_WASM_OUTPUT_DIRECTORY="$OUT_DIR"
cmake --build "$BUILD_DIR" --target lightusd_core_wasm

sha256sum "$OUT_DIR/lightusd.wasm" | awk '{print $1}' > "$OUT_DIR/lightusd.sha256"
git -C "$LIGHTUSD_ROOT" rev-parse HEAD > "$OUT_DIR/lightusd.revision"
ls -la "$OUT_DIR"
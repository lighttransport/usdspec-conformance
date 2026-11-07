#!/usr/bin/env bash
# Build external consumers locally and retain a complete CTest execution report.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
lightusd="${LIGHTUSD_ROOT:-$HOME/work/tinyusdz/large-scene}"
jobs="${JOBS:-4}"
mkdir -p "$root/build"
python3 "$root/scripts/check-license-notices.py"
python3 "$root/scripts/extract-usda-peg.py" --lean
exec > >(tee "$root/build/verification.log") 2>&1
if [[ -L "$root/verif/lean/.lake" ]]; then
  cp -a --reflink=auto "$root/verif/lean/.lake/" "$root/build/lean-cache-copy"
  rm "$root/verif/lean/.lake"
  mv "$root/build/lean-cache-copy" "$root/verif/lean/.lake"
fi
export PATH="$HOME/.elan/bin:$PATH"
if [[ ! -f "$root/verif/lean/.lake/packages/mathlib/.lake/build/lib/lean/Mathlib/Data/List/Basic.olean" ]]; then
  (cd "$root/verif/lean" && lake exe cache get)
fi
python3 "$root/scripts/check-native-vector-copy.py" --lightusd "$lightusd"
cmake -S "$lightusd" -B "$root/build/lightusd" -G Ninja \
  -DCMAKE_RUNTIME_OUTPUT_DIRECTORY="$root/build/lightusd" -DCMAKE_BUILD_TYPE=Debug -DLIGHTUSD_NATIVE_PRODUCT=next \
  -DLIGHTUSD_BUILD_TOOLS=ON -DLIGHTUSD_NEXT_BUILD_TESTS=ON
cmake --build "$root/build/lightusd" --parallel "$jobs" --target \
  lusdcat lusdchecker test_name_order test_int64_listop test_lean_vectors \
  test_aousd_conformance test_aousd_value_resolution
ORACLE_PYTHON="${ORACLE_PYTHON:-python3.11}" "$root/scripts/setup-oracle.sh"
export AOUSD_SUPPLEMENTAL_CACHE="${AOUSD_SUPPLEMENTAL_CACHE:-$root/build/aousd-supplemental}"
suite="${AOUSD_SUPPLEMENTAL_ROOT:-}"
if [[ -z "$suite" ]]; then
  for cache in "$HOME/.cache/lightusd/core-spec-supplemental-release_dec2025" "$HOME/.cache/usdspec-conformance/core-spec-supplemental-release_dec2025"; do
    if [[ "$(git -C "$cache" rev-parse HEAD 2>/dev/null || true)" == c15ae0cad3ed9e07a25dffd6699627d2c166cab0 ]]; then
      suite="$cache/releases/1.0.1"
      break
    fi
  done
fi
if [[ -z "$suite" ]]; then suite="$("$root/scripts/fetch-aousd-supplemental.sh" | tail -1)"; fi
python3 "$root/scripts/fetch-lean-unicode-data.py"
openusd="${OPENUSD_ROOT:-$HOME/work/tinyusdz/OpenUSD}"
local_python="${LOCAL_ORACLE_PYTHON:-$openusd/.venv/bin/python3}"
for checkout in "$root" "$lightusd" "$openusd"; do
  echo "Repository: $checkout"
  git -C "$checkout" rev-parse HEAD
  git -C "$checkout" status --short --untracked-files=no
done
(cd "$root/verif/lean" && lake env lean --version)
"$local_python" --version
cmake -S "$openusd" -B "$root/build/openusd-local-build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$root/build/openusd-local" \
  -DPXR_BUILD_IMAGING=OFF -DPXR_BUILD_USD_IMAGING=OFF -DPXR_BUILD_USDVIEW=OFF \
  -DPXR_BUILD_TESTS=OFF -DPXR_BUILD_EXAMPLES=OFF -DPXR_BUILD_TUTORIALS=OFF \
  -DPXR_ENABLE_PYTHON_SUPPORT=ON -DPXR_PYTHON_INSTALL_DIR=lib/python -DPython3_EXECUTABLE="$local_python" \
  -DCMAKE_PREFIX_PATH="$openusd/deps/inst"
cmake --build "$root/build/openusd-local-build" --parallel "$jobs"
cmake --install "$root/build/openusd-local-build"
cmake -S "$root" -B "$root/build" -DUSDSPEC_REQUIRE_FULL_SUITE=ON \
  -DLOCAL_OPENUSD_ROOT="$openusd" -DLOCAL_OPENUSD_PREFIX="$root/build/openusd-local" \
  -DLOCAL_ORACLE_PYTHON="$local_python" \
  -DLIGHTUSD_ROOT="$lightusd" -DLIGHTUSD_BUILD_DIR="$root/build/lightusd" \
  -DORACLE_PYTHON="${ORACLE_PYTHON:-python3.11}" \
  -DORACLE_PYTHONPATH="$root/build/stock-openusd-oracle/site-packages" \
  -DAOUSD_SUPPLEMENTAL_ROOT="$suite"
env -u LD_LIBRARY_PATH -u PXR_PLUGINPATH_NAME USDSPEC_ORACLE_MODE=stock PYTHONPATH="$root/build/stock-openusd-oracle/site-packages" \
  "${ORACLE_PYTHON:-python3.11}" "$root/scripts/oracle-provenance.py" > "$root/build/stock-provenance.json"
USDSPEC_ORACLE_MODE=local USDSPEC_LOCAL_ROOT="$openusd" \
  USDSPEC_LOCAL_PREFIX="$root/build/openusd-local" \
  PYTHONPATH="$root/build/openusd-local/lib/python" \
  LD_LIBRARY_PATH="$root/build/openusd-local/lib" \
  PXR_PLUGINPATH_NAME="$root/build/openusd-local/plugin/usd" \
  "$local_python" "$root/scripts/oracle-provenance.py" > "$root/build/local-provenance.json"
ctest --test-dir "$root/build" -j2 --output-on-failure --output-junit results.xml
python3 - "$root/build/results.xml" <<'PYTHON'
import sys
import xml.etree.ElementTree as ET
suite = ET.parse(sys.argv[1]).getroot()
assert list(suite.iter('testcase')), 'No tests executed'
assert not list(suite.iter('skipped')), 'Full verification must not skip tests'
PYTHON

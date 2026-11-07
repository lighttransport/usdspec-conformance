#!/usr/bin/env bash
# Install the stock OpenUSD oracle (official usd-core wheel) into build/ and
# print the cmake flags that use it. The local OpenUSD fork is NOT valid
# evidence for conformance claims.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
version="${USD_CORE_VERSION:-26.11}"
py="${ORACLE_PYTHON:-python3.11}"
target="$root/build/stock-openusd-oracle/site-packages"
if PYTHONPATH="$target" "$py" -c 'import sys; from pathlib import Path; import importlib.metadata, pxr; d=importlib.metadata.distribution("usd-core"); assert d.version == sys.argv[1]; assert Path(pxr.__file__).resolve() == Path(d.locate_file("pxr/__init__.py")).resolve(); assert Path(pxr.__file__).resolve().is_relative_to(Path(sys.argv[2]).resolve())' "$version" "$target" 2>/dev/null; then
  echo "-DORACLE_PYTHON=$py -DORACLE_PYTHONPATH=$target"
  exit 0
fi
"$py" -m pip install --target "$target" --no-deps "usd-core==$version"
echo "-DORACLE_PYTHON=$py -DORACLE_PYTHONPATH=$target"

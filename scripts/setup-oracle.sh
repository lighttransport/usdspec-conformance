#!/usr/bin/env bash
# Install the stock OpenUSD oracle (official usd-core wheel) into build/ and
# print the cmake flags that use it. The local OpenUSD fork is NOT valid
# evidence for conformance claims.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
version="${USD_CORE_VERSION:-26.11}"
py="${ORACLE_PYTHON:-python3.11}"
target="$root/build/stock-openusd-oracle/site-packages"
"$py" -m pip install --target "$target" --no-deps "usd-core==$version"
echo "-DORACLE_PYTHON=$py -DORACLE_PYTHONPATH=$target"

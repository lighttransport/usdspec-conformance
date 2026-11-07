#!/bin/bash
# Run repro.py with the codeless demo schemas registered.
# Needs OpenUSD's Python (pxr) on PYTHONPATH; PY defaults to python3.
cd "$(dirname "$0")"
PXR_PLUGINPATH_NAME="$PWD/plugin/resources" "${PY:-python3}" repro.py

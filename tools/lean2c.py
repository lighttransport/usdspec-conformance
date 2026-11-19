#!/usr/bin/env python3
"""lean2c: Lean spec -> generated C (curated lowerings).

Files in tools/templates/ are the versioned lowerings of Lean definitions to
c2lean-translatable C11. This tool copies them to lightusd-c/src/internal/
(as DO NOT EDIT generated code) or checks for drift.

Each template cites its Lean source and SPEC line in the header banner.
No generic Lean compiler is attempted (List/Rat/Mathlib need per-kernel
lowering to finite-width + explicit LusdResult + caller buffers).

Usage:
    python3 tools/lean2c.py [--out DIR]          # regenerate into DIR
    python3 tools/lean2c.py --check [--out DIR]  # fail on drift
Default DIR: $LUSD_SPEC_DIR/src/internal or ~/work/lightusd-c/src/internal.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATES = os.path.join(ROOT, "tools", "templates")
LUSD_DIR = os.environ.get("LUSD_SPEC_DIR", os.path.expanduser("~/work/lightusd-c"))

TEMPLATES_FILES = sorted(
    f
    for f in os.listdir(TEMPLATES)
    if f.startswith("lusd_spec_") and f.endswith((".h", ".c"))
)


def targets(out_dir):
    return [(os.path.join(TEMPLATES, f), os.path.join(out_dir, f)) for f in TEMPLATES_FILES]


def main():
    out_dir = os.environ.get("LUSD_SPEC_OUT", os.path.join(LUSD_DIR, "src", "internal"))
    check = False
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--check":
            check = True
        elif args[i] == "--out" and i + 1 < len(args):
            out_dir = args[i + 1]
            i += 1
        else:
            print(f"lean2c: unknown argument {args[i]}", file=sys.stderr)
            return 2
        i += 1
    if not TEMPLATES_FILES:
        print(f"lean2c: no templates in {TEMPLATES}", file=sys.stderr)
        return 2
    if check and not os.path.exists(out_dir):
        print(f"lean2c: output dir missing ({out_dir}); skipping", file=sys.stderr)
        return 77
    os.makedirs(out_dir, exist_ok=True)
    drift = 0
    for src, dst in targets(out_dir):
        with open(src, "rb") as f:
            want = f.read()
        if check:
            if not os.path.exists(dst):
                print(f"DRIFT   {dst} (missing)", file=sys.stderr)
                drift += 1
                continue
            with open(dst, "rb") as f:
                got = f.read()
            if got == want:
                print(f"ok      {dst}")
            else:
                print(f"DRIFT   {dst}", file=sys.stderr)
                drift += 1
        else:
            with open(dst, "wb") as f:
                f.write(want)
            print(f"wrote   {dst} ({len(want)} bytes)")
    if drift > 0:
        print(f"lean2c: {drift} file(s) differ; regenerate with --out", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

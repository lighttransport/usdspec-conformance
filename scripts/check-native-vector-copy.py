#!/usr/bin/env python3
"""Check that native consumers compile the canonical committed vector bytes."""
import argparse
from pathlib import Path
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--lightusd', required=True, type=Path)
args = parser.parse_args()
canonical = Path(__file__).resolve().parents[1] / 'tests/next/generated/lean'
native = args.lightusd / 'tests/core/generated/lean'
runtime_tables = {
    'openusd-domain-schema-registry.inc': args.lightusd / 'src/schema/generated',
}

def normalize_regeneration_comment(data):
    return b''.join(
        line.replace(b'../../tests/core/generated/lean', b'../../tests/next/generated/lean')
        if line.startswith(b'//   cd verif/lean && lake exe usdspec-gen --out ')
        else line
        for line in data.splitlines(keepends=True)
    )


problems = []
for artifact in canonical.iterdir():
    if not artifact.is_file():
        continue
    native_copy = runtime_tables.get(artifact.name, native) / artifact.name
    if not native_copy.is_file() or (
        artifact.read_bytes() != normalize_regeneration_comment(native_copy.read_bytes())
    ):
        problems.append(artifact.name)
if problems:
    parser.exit(1, 'Native vector copy missing or stale: ' + ', '.join(sorted(problems)) + '\n')
print('Native vector copy: all canonical artifacts agree')

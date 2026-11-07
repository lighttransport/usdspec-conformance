#!/usr/bin/env python3
"""Check that native consumers compile the canonical committed vector bytes."""
import argparse
from pathlib import Path
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--lightusd', required=True, type=Path)
args = parser.parse_args()
canonical = Path(__file__).resolve().parents[1] / 'tests/next/generated/lean'
native = args.lightusd / 'tests/next/generated/lean'
problems = [p.name for p in canonical.iterdir() if p.is_file() and
            (not (native / p.name).is_file() or p.read_bytes() != (native / p.name).read_bytes())]
if problems:
    parser.exit(1, 'Native vector copy missing or stale: ' + ', '.join(sorted(problems)) + '\n')
print('Native vector copy: all canonical artifacts agree')

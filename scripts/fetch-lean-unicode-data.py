#!/usr/bin/env python3
"""Fetch official Unicode data into an ignored cache and verify every byte."""
import argparse
import hashlib
from pathlib import Path
import urllib.request

from lean_unicode_ucd import DEFAULT_UCD_DIR, MANIFEST, read_reference


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ucd-dir', type=Path, default=DEFAULT_UCD_DIR)
    args = parser.parse_args()
    args.ucd_dir.mkdir(parents=True, exist_ok=True)
    for name, digest in MANIFEST['files'].items():
        path = args.ucd_dir / name
        if not path.exists():
            with urllib.request.urlopen(MANIFEST['base_url'] + name, timeout=30) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != digest:
                raise SystemExit(f'{name}: downloaded SHA256 mismatch')
            path.write_bytes(data)
        read_reference(args.ucd_dir, name)
        print(f'verified {name}')


if __name__ == '__main__':
    main()

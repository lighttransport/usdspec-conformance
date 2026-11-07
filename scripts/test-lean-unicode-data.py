#!/usr/bin/env python3
"""Check independent Unicode tables, negative trust controls and Lean conformance."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from lean_unicode_ucd import DEFAULT_UCD_DIR, MANIFEST, ROOT, read_reference


LIGHTUSD = None


def run(args, expected=0, diagnostic=None, cwd=ROOT):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    output = result.stdout + result.stderr
    if result.returncode != expected or (diagnostic and diagnostic not in output):
        raise SystemExit(f'Unicode gate failed: {args}\n{output}')
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ucd-dir', type=Path, default=DEFAULT_UCD_DIR)
    parser.add_argument('--conformance', action='store_true')
    parser.add_argument('--lake', default='lake')
    args = parser.parse_args()
    global LIGHTUSD
    LIGHTUSD = Path(os.environ['LIGHTUSD_ROOT']) if os.environ.get('LIGHTUSD_ROOT') else None
    args.ucd_dir = args.ucd_dir.resolve()
    for name in MANIFEST['files']:
        read_reference(args.ucd_dir, name)
    xid = [sys.executable, str(ROOT / 'scripts/generate-lean-xid-table.py')]
    norm = [sys.executable, str(ROOT / 'scripts/generate-lean-unicode-tables.py')]
    for command in [xid, norm]:
        run(command + ['--check', '--ucd-dir', str(args.ucd_dir)])
    with tempfile.TemporaryDirectory(prefix='lightusd-unicode-trust-') as directory:
        base = Path(directory)
        # Corrupted reference data must not become a new independent oracle.
        reference = base / 'DerivedCoreProperties.txt'
        reference.write_bytes((args.ucd_dir / reference.name).read_bytes() + b'\n')
        run(xid + ['--check', '--ucd-dir', str(base)], 1, 'SHA256 mismatch')
        # Native drift must fail even when the committed Lean table is intact.
        if LIGHTUSD is not None:
            native = base / 'native.c'
            text = (LIGHTUSD / 'src/unicode-xid-c.c').read_text()
            assert '{0x41u, 0x5au}' in text
            native.write_text(text.replace('{0x41u, 0x5au}', '{0x40u, 0x5au}', 1))
            run(xid + ['--check', '--ucd-dir', str(args.ucd_dir), '--source', str(native)],
                1, 'native ranges differ')
        else:
            print('note: LIGHTUSD_ROOT unset; native-drift control skipped')
        # Generated output drift is separate from input/native provenance.
        output = base / 'NormTables.lean'
        output.write_text('-- stale generated table\n')
        run(norm + ['--check', '--ucd-dir', str(args.ucd_dir), '--out', str(output)],
            1, 'DRIFT')
        run(norm + ['--check', '--ucd-dir', str(base / 'missing')], 1, 'missing')
    print('Unicode 15.1: independent native/Lean tables and four negative trust controls pass')
    if args.conformance:
        print(run([args.lake, 'exe', 'usdspec-check-unicode',
                   str(args.ucd_dir / 'NormalizationTest.txt')],
                  cwd=ROOT / 'verif/lean'), end='')


if __name__ == '__main__':
    sys.exit(main())

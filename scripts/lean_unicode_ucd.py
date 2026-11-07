"""Read the hash-pinned Unicode 15.1 reference data, independent of native tables."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / 'verif/lean/data/unicode-15.1.0.json'
MANIFEST = json.loads(MANIFEST_PATH.read_text(encoding='utf-8'))
VERSION = MANIFEST['version']
DEFAULT_UCD_DIR = ROOT / 'build' / ('unicode-' + VERSION)


def read_reference(directory, name):
    path = Path(directory) / name
    try:
        data = path.read_bytes()
    except FileNotFoundError:
        raise SystemExit(f'{path}: missing; run scripts/fetch-lean-unicode-data.py')
    digest = hashlib.sha256(data).hexdigest()
    if digest != MANIFEST['files'][name]:
        raise SystemExit(f'{path}: SHA256 mismatch; refusing unpinned Unicode data')
    return data.decode('utf-8')


def property_ranges(directory, filename, property_name):
    ranges = []
    for line in read_reference(directory, filename).splitlines():
        fields = line.split('#', 1)[0].strip().split(';')
        if len(fields) < 2 or fields[1].strip() != property_name:
            continue
        bounds = [int(cp, 16) for cp in fields[0].strip().split('..')]
        lo, hi = bounds[0], bounds[-1]
        if not 0 <= lo <= hi <= 0x10ffff:
            raise SystemExit(f'{filename}: invalid range for {property_name}')
        ranges.append((lo, hi))
    if not ranges:
        raise SystemExit(f'{filename}: missing property {property_name}')
    merged = []
    for lo, hi in sorted(ranges):
        if merged and lo <= merged[-1][1]:
            raise SystemExit(f'{filename}: overlapping {property_name} ranges')
        if merged and lo == merged[-1][1] + 1:
            merged[-1] = (merged[-1][0], hi)
        else:
            merged.append((lo, hi))
    return merged

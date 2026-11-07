#!/usr/bin/env python3
"""Check redistribution boundaries and notices without licensing local grammar output."""
from pathlib import Path
import hashlib
import subprocess


def require(condition, message):
    if not condition:
        raise SystemExit(message)


root = Path(__file__).resolve().parents[1]
for name in ('licenses/Unicode-LICENSE', 'THIRD_PARTY_NOTICES.md'):
    require((root / name).is_file(), f'Missing notice: {name}')
for row in (root / 'licenses/SHA256SUMS').read_text().splitlines():
    digest, name = row.split(maxsplit=1)
    require(hashlib.sha256((root / 'licenses' / name).read_bytes()).hexdigest() == digest,
            f'Notice changed: {name}')
for row in (root / 'aousd/core/1.1.0/SHA256SUMS').read_text().splitlines():
    digest, name = row.split(maxsplit=1)
    data = (root / 'aousd/core/1.1.0' / name.strip().lstrip('*')).read_bytes()
    require(hashlib.sha256(data).hexdigest() == digest, f'Licensed source changed: {name}')
facade = (root / 'verif/lean/UsdSpec/Usda/Rules.lean').read_text()
require('import UsdSpec.Usda.GeneratedRules' in facade, 'Missing local grammar import')
require('def usda' not in facade, 'Transformed grammar must not be distributed')
for name in ('NormTables.lean', 'XidTable.lean'):
    text = (root / 'verif/lean/UsdSpec/Unicode' / name).read_text()
    require('licenses/Unicode-LICENSE' in text and '2023 Unicode' in text,
            f'Missing Unicode attribution: {name}')
ignored = 'verif/lean/UsdSpec/Usda/GeneratedRules.lean'
require('/' + ignored in (root / '.gitignore').read_text().splitlines(),
        'Local grammar must remain excluded from Git')
if (root / '.git').exists():
    tracked = subprocess.check_output(['git', 'ls-files', '--', ignored], cwd=root, text=True)
    require(not tracked.strip(), 'Local transformed grammar was added to Git')
print('License notices, original-source hashes and local grammar boundary pass')

#!/usr/bin/env python3
"""Read every legal crate list-op header through LightUSD and stock OpenUSD."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ORACLE = r'''
import importlib.metadata, json, pathlib, sys
import pxr
from pxr import Sdf
package = importlib.metadata.distribution('usd-core')
assert package.version == '26.11', package.version
assert pathlib.Path(pxr.__file__).resolve() == pathlib.Path(package.locate_file('pxr/__init__.py')).resolve()
data = json.load(sys.stdin)
for case in data['cases']:
    layer = Sdf.Layer.FindOrOpen(str(pathlib.Path(data['directory']) / case['file']))
    assert layer
    op = layer.GetPrimAtPath('/P').GetInfo('inactiveIds')
    if case.get('kind') == 'roundtrip':
        rewritten = Sdf.Layer.FindOrOpen(str(pathlib.Path(data['directory']) / case['rewritten']))
        op = layer.GetObjectAtPath(case.get('spec', '/P')).GetInfo(case['field'])
        other = rewritten.GetObjectAtPath(case.get('spec', '/P')).GetInfo(case['field'])
        assert layer.GetObjectAtPath(case.get('spec', '/P')).HasInfo(case['field']) == rewritten.GetObjectAtPath(case.get('spec', '/P')).HasInfo(case['field']), (case['file'], 'authored field presence')
        assert op.isExplicit == other.isExplicit, (case['file'], 'mode', op, other)
        for name in ['explicitItems', 'addedItems', 'prependedItems', 'appendedItems', 'deletedItems', 'orderedItems']:
            assert list(getattr(op, name)) == list(getattr(other, name)), (case['file'], name, op, other)
        continue
    expected = {'explicit': op.isExplicit,
                'runs': [list(getattr(op, name)) for name in
                         ['explicitItems', 'addedItems', 'prependedItems',
                          'appendedItems', 'deletedItems', 'orderedItems']],
                'effective': list(op.ApplyOperations([]))}
    for name, value in expected.items():
        assert case[name] == value, (case['file'], name, case[name], value)
print('Stock 26.11 list-op modes: %d real crate fields passed' % len(data['cases']))
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tool', required=True)
    parser.add_argument('--oracle-python', required=True)
    parser.add_argument('--oracle-pythonpath', required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='lightusd-listop-modes-') as directory:
        result = subprocess.run([args.tool, '--header-cases', directory], text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=120)
        if result.returncode:
            raise RuntimeError(result.stderr)
        cases = json.loads(result.stdout)
        assert len(cases) == 2048
        expected_files = {f'{empty}-{header}.usdc' for empty in range(2) for header in range(128)}
        expected_files.update(f'{family}-{empty}-{header}.usdc'
            for family in ['token', 'string', 'path', 'reference', 'payload', 'relationship', 'connection']
            for empty in range(2) for header in range(128))
        assert {case['file'] for case in cases} == expected_files

        assert {case['header'] for case in cases if 'header' in case} == set(range(128))
        env = dict(os.environ)
        env['PYTHONPATH'] = str(Path(args.oracle_pythonpath).resolve())
        env.pop('LD_LIBRARY_PATH', None)
        env.pop('PXR_PLUGINPATH_NAME', None)
        oracle = subprocess.run([args.oracle_python, '-c', ORACLE], text=True,
            input=json.dumps({'directory': directory, 'cases': cases}), env=env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=120)
        if oracle.returncode:
            raise RuntimeError(oracle.stderr)
        print(oracle.stdout.strip())


if __name__ == '__main__':
    main()

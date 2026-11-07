#!/usr/bin/env python3
"""Compare shared name ordering and stage property ordering with stock OpenUSD."""
import argparse
import json
import os
from pathlib import Path
import random
import subprocess
import tempfile

ORACLE = r'''
import importlib.metadata, json, pathlib, sys
import pxr
from pxr import Sdf, Tf, Usd
package = importlib.metadata.distribution('usd-core')
assert package.version == '26.11', package.version
assert pathlib.Path(pxr.__file__).resolve() == pathlib.Path(package.locate_file('pxr/__init__.py')).resolve()
data = json.load(sys.stdin)
comparisons = [Tf.DictionaryStrcmp(a, b) for a, b in data['pairs']]
stage = Usd.Stage.CreateInMemory()
prim = stage.DefinePrim('/P')
for i, name in enumerate(data['names']):
    if i % 3:
        prim.CreateAttribute(name, Sdf.ValueTypeNames.Int)
    else:
        prim.CreateRelationship(name)
scenarios = []
for order in [[], ['foo10', 'foo2'], ['foo01', 'foo1', '_foo']]:
    prim.SetPropertyOrder(order)
    scenarios.append({'source': stage.GetRootLayer().ExportToString(),
                      'names': prim.GetPropertyNames()})
json.dump({'comparisons': comparisons, 'scenarios': scenarios}, sys.stdout)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tool', required=True)
    parser.add_argument('--oracle-python', required=True)
    parser.add_argument('--oracle-pythonpath', required=True)
    args = parser.parse_args()
    rng = random.Random(20261106)
    atoms = ['', '_', 'A', 'a', 'B', 'b', '0', '00', '01', '1', '2', '10',
             ':', '.', '-', '@', '[', '`', '{', '~', 'é', '中', '😀']
    names = sorted(set(atoms + [rng.choice(atoms) + rng.choice(atoms) + rng.choice(atoms)
                               for _ in range(260)]))
    names += ['x' + '9' * 500, 'x1' + '0' * 500, 'x' + '0' * 600 + '1']
    pairs = [(a, b) for a in names for b in names]
    property_names = ['foo10', 'foo2', 'foo01', 'foo1', 'Foo1', '_foo', 'a0',
                      'a00', 'a1b', 'a01a', 'a_1', 'a2', 'a10', 'é', '中',
                      'ns:x10', 'ns:x2', 'NS:X2']
    env = dict(os.environ)
    env['PYTHONPATH'] = str(Path(args.oracle_pythonpath).resolve())
    env.pop('LD_LIBRARY_PATH', None)
    env.pop('PXR_PLUGINPATH_NAME', None)
    oracle = subprocess.run([args.oracle_python, '-c', ORACLE],
        input=json.dumps({'pairs': pairs, 'names': property_names}), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, check=True, timeout=120)
    expected = json.loads(oracle.stdout)
    result = subprocess.run([args.tool, '--compare'],
        input=''.join(a + '\t' + b + '\n' for a, b in pairs), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=120)
    actual = [int(line) for line in result.stdout.splitlines()]
    assert len(actual) == len(pairs)
    for pair, got, truth in zip(pairs, actual, expected['comparisons']):
        sign = (truth > 0) - (truth < 0)
        assert got == sign, (pair, got, sign)
    with tempfile.TemporaryDirectory(prefix='lightusd-name-order-') as directory:
        root = Path(directory) / 'root.usda'
        for scenario in expected['scenarios']:
            root.write_text(scenario['source'])
            result = subprocess.run([args.tool, '--properties', str(root), '/P'],
                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=120)
            assert result.stdout.splitlines() == scenario['names'], (
                result.stdout.splitlines(), scenario['names'])
    print(f'Stock 26.11 name ordering: {len(pairs)} comparisons and 3 stage-order scenarios passed')


if __name__ == '__main__':
    main()

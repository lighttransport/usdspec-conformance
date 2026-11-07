#!/usr/bin/env python3
"""Validate Lean's terminating sublayer traversal through native and stock PCP."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ORACLE = r'''
import importlib.util, json, pathlib, sys
spec = importlib.util.spec_from_file_location('oracle', sys.argv[1])
oracle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oracle)
provenance = oracle.oracle_provenance('26.11')
out = []
for root in json.loads(pathlib.Path(sys.argv[2]).read_text()):
    truth = oracle.dump(root, provenance, {})
    assert truth['status'] == 'ok', truth
    out.append(truth)
print(json.dumps(out))
'''


def verify(case, document, diagnostics, label):
    if document['Layer Stack'] != case['layers']:
        raise AssertionError((label, case['id'], 'layer stack', case['layers'], document['Layer Stack']))
    prim = document['Composing']['/P']
    if prim['Prim Stack'] != case['expected']:
        raise AssertionError((label, case['id'], 'prim stack', case['expected'], prim['Prim Stack']))
    expected = [{'layer': entry['layer'], 'path': entry['path'] + '.marker'}
                for entry in case['expected']]
    if prim['Property stacks']['/P.marker'] != expected:
        raise AssertionError((label, case['id'], 'property stack', expected, prim))
    # Compare required diagnostic presence, not error counts: stock may return
    # the same layer-stack error from several prim-index requests.
    if any(issue['kind'] == 'cycle' for issue in case['issues']):
        if 'cycle' not in diagnostics.lower():
            raise AssertionError((label, case['id'], 'missing cycle diagnostic', diagnostics))
    for issue in case['issues']:
        if issue['kind'] == 'missing' and issue['layer'] not in diagnostics:
            raise AssertionError((label, case['id'], 'missing layer diagnostic', diagnostics))
    if not case['issues'] and diagnostics.strip():
        raise AssertionError((label, case['id'], 'unexpected diagnostics', diagnostics))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lusdcat', required=True, type=Path)
    parser.add_argument('--vectors', type=Path, default=HERE / 'generated/lean/layer-stack-vectors.json')
    parser.add_argument('--oracle-python')
    parser.add_argument('--oracle-pythonpath')
    args = parser.parse_args()
    cases = json.loads(args.vectors.read_text())['cases']
    if len(cases) != 94 or len({case['id'] for case in cases}) != 94:
        raise AssertionError('layer-stack vector count changed or IDs are duplicated')
    tool = str(args.lusdcat.resolve())
    with tempfile.TemporaryDirectory(prefix='lightusd-lean-layerstack-') as directory:
        roots = []
        for case in cases:
            folder = Path(directory) / case['id']
            folder.mkdir()
            for filename, text in case['files'].items():
                (folder / filename).write_text(text)
            root = folder / 'root.usda'
            result = subprocess.run([tool, '--dump-pcp-json', '-', '--pcp-json-version', '2',
                                     str(root)], capture_output=True, text=True)
            if result.returncode:
                raise AssertionError((case['id'], result.stderr))
            verify(case, json.loads(result.stdout), result.stderr, 'native')
            roots.append(str(root))
        if args.oracle_python:
            env = os.environ.copy()
            if args.oracle_pythonpath:
                env['PYTHONPATH'] = str(Path(args.oracle_pythonpath).resolve())
                if os.environ.get('USDSPEC_ORACLE_MODE', 'stock') != 'local':
                    env.pop('LD_LIBRARY_PATH', None)
                if os.environ.get('USDSPEC_ORACLE_MODE', 'stock') != 'local':
                    env.pop('PXR_PLUGINPATH_NAME', None)
            request = Path(directory) / 'requests.json'
            request.write_text(json.dumps(roots))
            result = subprocess.run([args.oracle_python, '-c', ORACLE,
                str(HERE / 'dump-pcp-oracle.py'), str(request)],
                capture_output=True, text=True, env=env)
            if result.returncode:
                raise AssertionError(result.stderr)
            truths = json.loads(result.stdout)
            if len(truths) != len(cases):
                raise AssertionError('stock oracle omitted layer-stack cases')
            for case, truth in zip(cases, truths):
                verify(case, truth, '\n'.join(truth['Composition errors']), 'stock')
    print(f'Lean layer stack: {len(cases)} graph/error cases pass native' +
          (' and selected OpenUSD oracle' if args.oracle_python else ''))


if __name__ == '__main__':
    main()

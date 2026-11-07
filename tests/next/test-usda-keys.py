#!/usr/bin/env python3
"""Check Lean-printed dictionary keys through native transports and stock Sdf."""
import argparse
import ast
import json
import os
from pathlib import Path
import subprocess
import tempfile

ORACLE = r'''
import importlib.metadata, json, pathlib, sys, tempfile
import pxr
from pxr import Sdf
package = importlib.metadata.distribution('usd-core')
assert package.version == '26.11', package.version
assert pathlib.Path(pxr.__file__).resolve() == pathlib.Path(package.locate_file('pxr/__init__.py')).resolve()
def expected(key, kind):
    return {key: 7 if kind == 0 else 'payload' if kind == 1 else {key: 'payload'}}
checks = losses = exact = 0
with tempfile.TemporaryDirectory(prefix='lightusd-stock-keys-') as directory:
    for case in json.load(sys.stdin):
        key, kind = case['key'], case['kind']
        for text in [case['source'], case['native_text']] + ([case['binary_text']] if case['binary_text'] is not None else []):
            layer = Sdf.Layer.CreateAnonymous('.usda')
            assert layer.ImportFromString(text), case['id']
            actual = dict(layer.GetPrimAtPath('/P').customData)
            assert actual == expected(key, kind), (case['id'], actual, expected(key, kind))
            checks += 1
        layer = Sdf.Layer.CreateAnonymous('.usda')
        assert layer.ImportFromString(case['source'])
        path = str(pathlib.Path(directory) / (case['id'] + '.usdc'))
        assert layer.Export(path)
        binary = Sdf.Layer.FindOrOpen(path)
        actual = dict(binary.GetPrimAtPath('/P').customData)
        if '\0' in key:
            assert actual == expected(key.split('\0')[0], kind) and actual != expected(key, kind), (case['id'], actual)
            losses += 1
        else:
            assert actual == expected(key, kind), (case['id'], actual)
            exact += 1
assert checks == 399 and exact == 129 and losses == 6, (checks, exact, losses)
print('Stock 26.11: 135 dictionary-key cases retained; 399 source/native-text/native-crate checks; 129 exact stock crate roundtrips; 6 classified stock NUL-key truncations, rejected by native crate writer')
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lusdcat', required=True)
    parser.add_argument('--oracle-python', required=True)
    parser.add_argument('--oracle-pythonpath', required=True)
    args = parser.parse_args()
    table = Path(__file__).resolve().parent / 'generated/lean/usda-key-vectors.inc'
    rows = [ast.literal_eval('(' + line[len('LEAN_USDA_KEY('):-1] + ')')
            for line in table.read_text().splitlines() if line.startswith('LEAN_USDA_KEY(')]
    keys = [chr(i) for i in range(32)] + [
        '\\', '"', chr(127), 'é中文🙂', 'a\nb\rc\td', 'nul\0' + '7', '\\n\\134"', '',
        'key with space', 'a-b', '7leading', 'def', 'namespace:key']
    # Independently pin the complete manifest and embedded-NUL literal decoding.
    assert len(rows) == 135
    assert {(id, key, kind) for id, _, key, kind in rows} == {
        (f'key-{index}-{kind}', key, kind) for index, key in enumerate(keys) for kind in range(3)}
    cases = []
    with tempfile.TemporaryDirectory(prefix='lightusd-quoted-keys-') as directory:
        root = Path(directory) / 'root.usda'
        binary = root.with_suffix('.usdc')
        for id, source, key, kind in rows:
            root.write_text(source)
            text = subprocess.run([args.lusdcat, '--rewrite-layer', str(root)],
                capture_output=True, text=True, check=True).stdout
            result = subprocess.run([args.lusdcat, '--rewrite-layer', '-o', str(binary), str(root)],
                capture_output=True, text=True)
            binary_text = None
            if '\0' in key:
                assert result.returncode != 0 and 'NUL' in result.stderr, (id, result.stderr)
            else:
                assert result.returncode == 0, (id, result.stderr)
                binary_text = subprocess.run([args.lusdcat, '--rewrite-layer', str(binary)],
                    capture_output=True, text=True, check=True).stdout
            cases.append({'id': id, 'source': source, 'key': key, 'kind': kind,
                          'native_text': text, 'binary_text': binary_text})
        env = dict(os.environ)
        env['PYTHONPATH'] = str(Path(args.oracle_pythonpath).resolve())
        env.pop('LD_LIBRARY_PATH', None)
        env.pop('PXR_PLUGINPATH_NAME', None)
        result = subprocess.run([args.oracle_python, '-c', ORACLE], input=json.dumps(cases),
            capture_output=True, text=True, env=env, timeout=120)
        if result.returncode:
            raise RuntimeError(result.stderr)
        print(result.stdout.strip())


if __name__ == '__main__':
    main()

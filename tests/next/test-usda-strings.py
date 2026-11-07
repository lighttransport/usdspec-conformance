#!/usr/bin/env python3
"""Validate Lean-emitted quoted strings against native transports and stock Sdf."""
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
checks = losses = 0
with tempfile.TemporaryDirectory(prefix='lightusd-stock-strings-') as directory:
    for case in json.load(sys.stdin):
        expected = case['value']
        for text in [case['source'], case['native_text']] + ([case['binary_text']] if case['binary_text'] is not None else []):
            layer = Sdf.Layer.CreateAnonymous('.usda')
            assert layer.ImportFromString(text), case['id']
            assert layer.GetPrimAtPath('/P').customData['s'] == expected, case['id']
            checks += 1
        layer = Sdf.Layer.CreateAnonymous('.usda')
        assert layer.ImportFromString(case['source'])
        path = str(pathlib.Path(directory) / (case['id'] + '.usdc'))
        assert layer.Export(path)
        binary = Sdf.Layer.FindOrOpen(path)
        actual = binary.GetPrimAtPath('/P').customData['s']
        if '\0' in expected:
            assert actual == expected.split('\0')[0] and actual != expected, case['id']
            losses += 1
        else:
            assert actual == expected, case['id']
assert checks == 118 and losses == 2, (checks, losses)
print('Stock 26.11: 40 cases retained, 118 source/native-text/native-crate value checks, 38 stock crate roundtrips, 2 classified stock NUL truncations; native rejects both unrepresentable crate values')
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lusdcat', required=True)
    parser.add_argument('--oracle-python', required=True)
    parser.add_argument('--oracle-pythonpath', required=True)
    args = parser.parse_args()
    table = Path(__file__).resolve().parent / 'generated/lean/usda-string-vectors.inc'
    rows = [ast.literal_eval('(' + line[len('LEAN_USDA_STRING('):-1] + ')')
            for line in table.read_text().splitlines() if line.startswith('LEAN_USDA_STRING(')]
    assert len(rows) == 40 and {row[0] for row in rows} == {f'string-{i}' for i in range(40)}
    # Independent values also check the C++ literal emitter, including NUL
    # followed by a digit; do not let a shared source/expectation bug cancel.
    values = {id: value for id, _, value in rows}
    expected = [chr(i) for i in range(32)] + [
        '\\', '"', chr(127), 'é中文🙂', 'a\nb\rc\td', 'nul\0' + '7', '\\n\\134"', '']
    assert values == {f'string-{i}': value for i, value in enumerate(expected)}
    cases = []
    with tempfile.TemporaryDirectory(prefix='lightusd-quoted-strings-') as directory:
        root = Path(directory) / 'root.usda'
        binary = root.with_suffix('.usdc')
        for id, source, value in rows:
            root.write_text(source)
            text = subprocess.run([args.lusdcat, '--rewrite-layer', str(root)],
                capture_output=True, text=True, check=True).stdout
            result = subprocess.run([args.lusdcat, '--rewrite-layer', '-o', str(binary), str(root)],
                capture_output=True, text=True)
            binary_text = None
            if '\0' in value:
                assert result.returncode != 0 and 'NUL' in result.stderr, (id, result.stderr)
            else:
                assert result.returncode == 0, (id, result.stderr)
                binary_text = subprocess.run([args.lusdcat, '--rewrite-layer', str(binary)],
                    capture_output=True, text=True, check=True).stdout
            cases.append({'id': id, 'source': source, 'value': value,
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

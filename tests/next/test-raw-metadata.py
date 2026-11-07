#!/usr/bin/env python3
"""Compare local unregistered-metadata folding with stock Sdf authoring."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ORACLE = Path(__file__).with_name('oracle_runtime.py').read_text() + "\noracle_provenance()\n" + r'''
import importlib.metadata, json, pathlib, re, sys
from collections import Counter
import pxr
from pxr import Sdf, Tf
pattern = r'^\s*(?:(add|prepend|append|delete|reorder)\s+)?pipelineTags\s*='
def assignments(text):
    return Counter(re.findall(pattern, text, re.M))
def values(text):
    return Counter(re.findall(r'^\s*((?:(?:add|prepend|append|delete|reorder)\s+)?pipeline(?:Tags|Other))\s*=\s*(.*?)\s*$', text, re.M))
checks = 0
rejected = 0
for case in json.load(sys.stdin):
    expected = Sdf.Layer.CreateAnonymous('.usda')
    if case['stock_reject']:
        try:
            accepted = expected.ImportFromString(case['source'])
        except Tf.ErrorException as error:
            assert 'ListValueItem' in str(error), str(error)
            accepted = False
        assert not accepted, (case['scope'], case['source'])
        rejected += 1
        continue
    assert expected.ImportFromString(case['source'])
    wanted = assignments(expected.ExportToString())
    for text in [case['text'], case['binary_text']]:
        assert assignments(text) == wanted, (case['scope'], case['source'], assignments(text), wanted)
        actual = Sdf.Layer.CreateAnonymous('.usda')
        assert actual.ImportFromString(text)
        assert values(expected.ExportToString()) == values(actual.ExportToString()), (case['scope'], case['source'], expected.ExportToString(), actual.ExportToString())
        checks += 1
assert checks == 64 and rejected == 4
print('OpenUSD 26.11 local metadata folding: 36 cases retained, %d accepted, %d classified text rejections, %d text/native-crate roundtrips passed' % (checks // 2, rejected, checks))
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lusdcat', required=True)
    parser.add_argument('--oracle-python', required=True)
    parser.add_argument('--oracle-pythonpath', required=True)
    args = parser.parse_args()
    patterns = [
        'prepend pipelineTags = ["a"]\nprepend pipelineTags = ["b"]',
        'prepend pipelineTags = ["a"]\nappend pipelineTags = ["c"]\nprepend pipelineTags = ["b"]',
        'prepend pipelineTags = ["a"]\npipelineTags = ["x"]',
        'pipelineTags = ["x"]\nprepend pipelineTags = ["b"]',
        'pipelineTags = ["x"]\nappend pipelineTags = ["c"]\npipelineTags = ["y"]\ndelete pipelineTags = ["z"]',
        'pipelineTags = ["a"]\npipelineTags = ["b"]',
        'prepend pipelineTags = ["a"]\nprepend pipelineTags = []',
        'pipelineOther = "keep"\nprepend pipelineTags = ["a"]\npipelineTags = None',
        '\n'.join(f'{q} pipelineTags = ["{v}"]' for q in
                  ['add', 'prepend', 'append', 'delete', 'reorder'] for v in ['a', 'b']),
    ]
    cases = []
    with tempfile.TemporaryDirectory(prefix='lightusd-raw-metadata-') as directory:
        root = Path(directory) / 'root.usda'
        binary = root.with_suffix('.usdc')
        for scope in ['Layer', 'Prim', 'Variant', 'Property']:
            for index, pattern in enumerate(patterns):
                if scope == 'Layer': source = f'({pattern})\ndef Scope "P" {{}}\n'
                elif scope == 'Prim': source = f'def Scope "P" ({pattern}) {{}}\n'
                elif scope == 'Variant': source = f'def Scope "P" {{\n variantSet "v" = {{\n "a" ({pattern}) {{}}\n }}\n}}\n'
                else: source = f'def Scope "P" {{\n int x = 1 ({pattern})\n}}\n'
                source = '#usda 1.0\n' + source
                root.write_text(source)
                text = subprocess.run([args.lusdcat, '--rewrite-layer', str(root)],
                    text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout
                subprocess.run([args.lusdcat, '--rewrite-layer', '-o', str(binary), str(root)],
                    text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
                binary_text = subprocess.run([args.lusdcat, '--rewrite-layer', str(binary)],
                    text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout
                cases.append({'scope': scope, 'source': source, 'text': text, 'binary_text': binary_text, 'stock_reject': index == 6})
        assert len(cases) == 36
        env = dict(os.environ)
        env['PYTHONPATH'] = str(Path(args.oracle_pythonpath).resolve())
        if os.environ.get('USDSPEC_ORACLE_MODE', 'stock') != 'local':
            env.pop('LD_LIBRARY_PATH', None)
        if os.environ.get('USDSPEC_ORACLE_MODE', 'stock') != 'local':
            env.pop('PXR_PLUGINPATH_NAME', None)
        result = subprocess.run([args.oracle_python, '-c', ORACLE], input=json.dumps(cases),
            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, timeout=120)
        if result.returncode: raise RuntimeError(result.stderr)
        print(result.stdout.strip())


if __name__ == '__main__':
    main()

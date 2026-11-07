#!/usr/bin/env python3
"""Oracle transport failures must not consume semantic-difference headroom."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

root = Path(__file__).resolve().parents[1]
path = root / 'tests/next/run-aousd-supplemental.py'
spec = importlib.util.spec_from_file_location('supplemental', path)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
manifest = json.loads(path.with_name('aousd-invalid-text.json').read_text())

class OracleFailures(unittest.TestCase):
    def check_failure(self, code, text, native_text='{}', expected=1):
        with tempfile.TemporaryDirectory() as directory:
            suite = Path(directory)
            (suite / 'LICENSE').touch()
            assets = suite / 'composition/tests/assets'
            names = list(manifest['cases'])
            names += [f'case{i}' for i in range(manifest['compositionCases'] - len(names))]
            for name in names:
                folder = assets / name
                folder.mkdir(parents=True)
                (folder / 'pcp.json').write_text(json.dumps({'Entry': 'root.usda', 'Composing': {}}))
            args = ['runner', '--suite-root', directory, '--lusdcat', '/fake/native',
                    '--category', 'composition', '--case', 'case0',
                    '--pcp-oracle-python', '/fake/oracle', '--max-pcp-oracle-diff', '15']
            success = types.SimpleNamespace(returncode=0, stdout=native_text, stderr='')
            oracle = types.SimpleNamespace(returncode=code, stdout=text, stderr='transport failure' if code else '')
            output = io.StringIO()
            with patch.object(sys, 'argv', args), patch.object(runner, 'run', return_value=success), patch.object(runner.subprocess, 'run', side_effect=[oracle, success]), contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                self.assertEqual(runner.main(), expected)
            if expected:
                self.assertIn('oracle_infrastructure', output.getvalue())
            else:
                self.assertNotIn('oracle_infrastructure', output.getvalue())

    def test_successful_native_document_without_status(self):
        self.check_failure(0, '{"schemaVersion":2,"status":"ok","Composing":{}}',
                           '{"schemaVersion":2,"Composing":{}}', expected=0)

    def test_crashed_oracle(self):
        self.check_failure(1, '')

    def test_invalid_json(self):
        self.check_failure(0, 'not json')

    def test_wrong_schema(self):
        self.check_failure(0, '{}')

if __name__ == '__main__':
    unittest.main()

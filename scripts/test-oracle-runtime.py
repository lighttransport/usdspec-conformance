#!/usr/bin/env python3
"""Regression checks for oracle provenance boundaries."""
import importlib.util
from pathlib import Path
import os
import types
import unittest
from unittest.mock import patch

source = Path(__file__).resolve().parents[1] / 'tests/next/oracle_runtime.py'
spec = importlib.util.spec_from_file_location('oracle_runtime', source)
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)

class ProvenanceTests(unittest.TestCase):
    def fixtures(self, module):
        return patch.dict('sys.modules', {'pxr': types.SimpleNamespace(
            __file__=module, Usd=types.SimpleNamespace(GetVersion=lambda: (0, 26, 11)))})

    def test_dump_supports_dynamic_import(self):
        dump_path = source.with_name('dump-pcp-oracle.py')
        dump_spec = importlib.util.spec_from_file_location('dump_fixture', dump_path)
        module = importlib.util.module_from_spec(dump_spec)
        dump_spec.loader.exec_module(module)
        self.assertTrue(callable(module.oracle_provenance))

    def test_unknown_mode_rejected(self):
        with self.fixtures('/stock/pxr/__init__.py'), patch.dict(os.environ, {'USDSPEC_ORACLE_MODE': 'typo'}, clear=True):
            with self.assertRaisesRegex(RuntimeError, 'unknown oracle mode'):
                runtime.oracle_provenance()

    def test_stock_rejects_shadowed_module(self):
        package = types.SimpleNamespace(version='26.11', locate_file=lambda _: '/stock/pxr/__init__.py')
        with self.fixtures('/other/pxr/__init__.py'), patch.dict(os.environ, {}, clear=True), patch.object(runtime.importlib.metadata, 'distribution', return_value=package):
            with self.assertRaisesRegex(RuntimeError, 'does not belong'):
                runtime.oracle_provenance()

    def test_stock_rejects_wrong_version(self):
        with self.fixtures('/stock/pxr/__init__.py'), patch.dict(os.environ, {}, clear=True), patch.object(runtime.importlib.metadata, 'distribution', return_value=types.SimpleNamespace(version='26.5')):
            with self.assertRaisesRegex(RuntimeError, 'expected usd-core'):
                runtime.oracle_provenance()

    def test_local_rejects_foreign_module(self):
        with self.fixtures('/stock/pxr/__init__.py'), patch.dict(os.environ, {'USDSPEC_ORACLE_MODE': 'local', 'USDSPEC_LOCAL_PREFIX': '/local', 'USDSPEC_LOCAL_ROOT': '/source'}, clear=True):
            with self.assertRaisesRegex(RuntimeError, 'outside configured prefix'):
                runtime.oracle_provenance()

    def test_local_records_checkout(self):
        with self.fixtures('/local/lib/python/pxr/__init__.py'), patch.dict(os.environ, {'USDSPEC_ORACLE_MODE': 'local', 'USDSPEC_LOCAL_PREFIX': '/local', 'USDSPEC_LOCAL_ROOT': '/source'}, clear=True), patch.object(runtime.subprocess, 'check_output', side_effect=['abc123\n', ' M file\n']):
            result = runtime.oracle_provenance()
            self.assertEqual(result['commit'], 'abc123')
            self.assertTrue(result['dirty'])
            self.assertEqual(result['kind'], 'local-checkout')

if __name__ == '__main__':
    unittest.main()

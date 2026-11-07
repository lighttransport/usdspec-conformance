#!/usr/bin/env python3
"""Regression checks for exact Lean declaration lookup and required binaries."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('check-lean-reflection.py')
spec = importlib.util.spec_from_file_location('reflection', SCRIPT)
reflection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reflection)


class ReflectionTests(unittest.TestCase):
    def test_exact_namespace_and_mutual_scope(self):
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, 'MisleadingModule.lean').write_text('''namespace Actual
mutual
def first := 1
def second := 2
end
section Example
def third := 3
end Example
inductive Fourth where
  | mk
end Actual
''')
            declarations = reflection.lean_declarations(directory)
        self.assertEqual(set(declarations),
                         {'Actual.first', 'Actual.second', 'Actual.third', 'Actual.Fourth'})
        self.assertIsNotNone(reflection.resolve('Actual.third', declarations))
        for name in ('Wrong.Actual.third', 'MisleadingModule.third', 'Other.third'):
            self.assertIsNone(reflection.resolve(name, declarations))

    def test_required_checker_cannot_silently_skip(self):
        with tempfile.TemporaryDirectory() as directory:
            table = Path(directory, 'src/next/validation')
            table.mkdir(parents=True)
            table.joinpath('validation-context.cc').write_text(
                '// BEGIN LEAN_REFLECTION_TABLE\n{"rule.x", "UsdSpec.ListOp.apply"},\n'
                '// END LEAN_REFLECTION_TABLE\n')
            result = subprocess.run(['python3', str(SCRIPT), '--require-lusdchecker',
                                     '--lightusd', directory,
                                     '--lusdchecker', '/nonexistent/lightusd-lusdchecker'],
                                    capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('required lusdchecker binary is missing', result.stdout)

    def test_missing_lightusd_is_a_skip_not_a_pass(self):
        env = {k: v for k, v in __import__('os').environ.items() if k != 'LIGHTUSD_ROOT'}
        result = subprocess.run(['python3', str(SCRIPT)], capture_output=True, text=True, env=env)
        self.assertEqual(result.returncode, 77)


if __name__ == '__main__':
    unittest.main()

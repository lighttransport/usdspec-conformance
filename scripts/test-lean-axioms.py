#!/usr/bin/env python3
"""Exercise the compiled-environment axiom audit, including private module helpers."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lake', default='lake')
    parser.add_argument('--case', help='Run one named fixture while debugging the audit')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    lean = root / 'verif/lean'
    audit = (lean / 'Audit/Axioms.lean').read_text().replace('import UsdSpec\n', '')
    cases = {
        'kernel': ('private theorem helper (x : Nat) : x = x := rfl\ntheorem witness (x : Nat) : x = x := helper x', True, ''),
        'axiom': ('axiom unsupported : True\ntheorem witness (x : Nat) : x = x := rfl', False, 'unsupported'),
        'sorry': ('theorem witness : True := by sorry', False, 'sorryAx'),
        'native': ('theorem witness : (123 : Nat) + 456 = 579 := by native_decide', False, 'native_decide'),
        'bitvector': ('theorem witness (x y : UInt8) : (x.toUInt16 ||| (y.toUInt16 <<< 8)).toUInt8 = x := by bv_decide', False, 'bv_decide'),
        'private': ('private axiom hidden : True\ntheorem witness : True := hidden', False, 'hidden'),
    }
    with tempfile.TemporaryDirectory(prefix='lightusd-lean-axioms-', dir=lean) as scratch:
        scratch = Path(scratch)
        env = dict(os.environ)
        env['LEAN_PATH'] = str(scratch) + os.pathsep + env.get('LEAN_PATH', '')
        for name, (body, accepted, diagnostic) in cases.items():
            if args.case and args.case != name:
                continue
            # Imported module-style declarations exercise private bodies and the
            # exported theorem presentation, rather than only local constants.
            fixture = scratch / 'Fixture.lean'
            fixture.write_text('module\npublic import Std.Tactic.BVDecide\n'
                               'public meta import Std.Tactic.BVDecide.Reflect\n'
                               'public section\nnamespace UsdSpec.AuditFixture\n'
                               + body + '\nend UsdSpec.AuditFixture\n')
            result = subprocess.run([args.lake, 'env', 'lean', '-o', str(scratch / 'Fixture.olean'),
                                     str(fixture)], cwd=lean, env=env, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
            if result.returncode:
                raise RuntimeError(f'{name}: fixture did not compile:\n{result.stdout}')
            check = scratch / 'Check.lean'
            check.write_text('import Fixture\n' + audit)
            result = subprocess.run([args.lake, 'env', 'lean', str(check)], cwd=lean, env=env,
                                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
            if (result.returncode == 0) != accepted or (not accepted and
                    ('UsdSpec axiom audit failed' not in result.stdout or diagnostic not in result.stdout)):
                raise RuntimeError(f'{name}: unexpected audit result:\n{result.stdout}')
            print(f'{name}: {"accepted kernel proof" if accepted else "rejected unapproved axiom"}', flush=True)
    if args.case and args.case not in cases:
        parser.error(f'unknown fixture: {args.case}')
    count = 1 if args.case else len(cases)
    print(f'Lean axiom audit tests: {count}/{count} passed')


if __name__ == '__main__':
    main()

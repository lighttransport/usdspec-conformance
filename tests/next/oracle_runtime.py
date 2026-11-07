"""Isolated stock-wheel and explicitly selected local-checkout provenance."""
import importlib.metadata
import os
from pathlib import Path
import subprocess


def oracle_provenance(expected='26.11'):
    import pxr
    from pxr import Usd
    module = Path(pxr.__file__).resolve()
    mode = os.environ.get('USDSPEC_ORACLE_MODE', 'stock')
    if mode not in ('stock', 'local'):
        raise RuntimeError(f'unknown oracle mode: {mode}')
    if mode == 'local':
        prefix = Path(os.environ['USDSPEC_LOCAL_PREFIX']).resolve()
        root = Path(os.environ['USDSPEC_LOCAL_ROOT']).resolve()
        if not module.is_relative_to(prefix):
            raise RuntimeError(f'local pxr outside configured prefix: {module}')
        version = '.'.join(str(x) for x in Usd.GetVersion()[1:])
        if version != expected:
            raise RuntimeError(f'expected local USD {expected}, got {version}')
        commit = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
        dirty = bool(subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain', '--untracked-files=no'], text=True))
        return {'package': 'local-checkout', 'kind': 'local-checkout',
                'version': '.'.join(str(x) for x in Usd.GetVersion()[1:]),
                'usdVersion': list(Usd.GetVersion()), 'commit': commit,
                'dirty': dirty, 'module': str(module)}
    distribution = importlib.metadata.distribution('usd-core')
    if distribution.version != expected:
        raise RuntimeError(f'expected usd-core=={expected}, got {distribution.version}')
    if tuple(Usd.GetVersion()) != (0, *(int(x) for x in expected.split('.'))):
        raise RuntimeError(f'wheel/runtime USD version mismatch: {Usd.GetVersion()}')
    if module != Path(distribution.locate_file('pxr/__init__.py')).resolve():
        raise RuntimeError('pxr module does not belong to the pinned usd-core distribution')
    return {'package': 'usd-core', 'version': distribution.version,
            'usdVersion': list(Usd.GetVersion())}

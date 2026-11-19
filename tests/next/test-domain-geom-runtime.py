#!/usr/bin/env python3
"""Compare PointInstancer runtime evaluation in OpenUSD and LightUSD.

For each scene, at each sampled time, compare per-instance transforms
(UsdGeom.PointInstancer.ComputeInstanceTransformsAtTime, ExcludeProtoXform)
and visibility masks (ComputeMaskAtTime) against `geom_compare
--dump-instancer`. The authored USDA and a LightUSD-written USDC copy are both
replayed through the native side.
"""
import argparse
import math
from pathlib import Path
import subprocess
import tempfile

from pxr import Usd, UsdGeom

HEAD = '#usda 1.0\n(\n    timeCodesPerSecond = 24\n)\n'
PROTO = 'def Xform "Protos" {\n    def Cube "A" {\n    }\n    def Sphere "B" {\n    }\n}\n'

SCENES = {
    "trs": (PROTO + '''
def PointInstancer "PI" {
    rel prototypes = [</Protos/A>, </Protos/B>]
    int[] protoIndices = [0, 1, 0]
    point3f[] positions = [(1,2,3), (-1,0,0.5), (0,0,0)]
    quath[] orientations = [(1,0,0,0), (0,0,1,0), (0.5,0.5,0.5,0.5)]
    float3[] scales = [(1,1,1), (2,0.5,1), (3,3,3)]
}
''', [0]),
    # 45 degrees about y is not representable in half precision; OpenUSD uses
    # the rounded quaternion without renormalizing while LightUSD normalizes.
    # Both stay inside the Lean unit-length tolerance
    # (pointInstancerQuaternionValid half: |q.q - 1| <= 1/500), which bounds
    # each matrix entry by 2 * (1/500) * max scale.
    "quantized-half": (PROTO + '''
def PointInstancer "PI" {
    rel prototypes = [</Protos/A>]
    int[] protoIndices = [0]
    point3f[] positions = [(-1,0,0.5)]
    quath[] orientations = [(0.70710678,0,0.70710678,0)]
    float3[] scales = [(2,0.5,1)]
}
''', [0], 2 * (1 / 500) * 2),
    "orientationsf": (PROTO + '''
def PointInstancer "PI" {
    rel prototypes = [</Protos/A>]
    int[] protoIndices = [0, 0]
    point3f[] positions = [(0,0,0), (1,1,1)]
    quatf[] orientationsf = [(0.92387953,0.38268343,0,0), (0,0,0,1)]
}
''', [0]),
    "sampled-positions": (PROTO + '''
def PointInstancer "PI" {
    rel prototypes = [</Protos/A>]
    int[] protoIndices = [0, 0]
    point3f[] positions.timeSamples = {0: [(0,0,0), (1,0,0)], 10: [(10,0,0), (1,10,0)]}
}
''', [0, 2.5, 10, 12]),
    "masks": (PROTO + '''
def PointInstancer "PI" (
    append inactiveIds = [10]
)
{
    rel prototypes = [</Protos/A>]
    int[] protoIndices = [0, 0, 0, 0]
    point3f[] positions = [(0,0,0), (1,0,0), (2,0,0), (3,0,0)]
    int64[] ids = [10, 11, 12, 13]
    int64[] invisibleIds.timeSamples = {0: [11], 5: [12, 13]}
}
''', [0, 4, 5]),
    "masks-no-ids": (PROTO + '''
def PointInstancer "PI" {
    rel prototypes = [</Protos/A>]
    int[] protoIndices = [0, 0, 0]
    point3f[] positions = [(0,0,0), (1,0,0), (2,0,0)]
    int64[] invisibleIds = [2]
}
''', [0]),
    "velocities": (PROTO + '''
def PointInstancer "PI" {
    rel prototypes = [</Protos/A>]
    int[] protoIndices = [0]
    point3f[] positions.timeSamples = {0: [(0,0,0)], 24: [(24,0,0)]}
    vector3f[] velocities.timeSamples = {0: [(24,0,0)], 24: [(24,0,0)]}
}
''', [0, 6, 12]),
    # Velocities that disagree with the position slope: OpenUSD extrapolates
    # from the earlier position sample with the velocity instead of
    # interpolating positions.
    "velocities-extrapolate": (PROTO + '''
def PointInstancer "PI" {
    rel prototypes = [</Protos/A>]
    int[] protoIndices = [0]
    point3f[] positions.timeSamples = {0: [(0,0,0)], 24: [(24,0,0)]}
    vector3f[] velocities.timeSamples = {0: [(48,0,0)], 24: [(48,0,0)]}
    vector3f[] angularVelocities.timeSamples = {0: [(0,0,90)], 24: [(0,0,90)]}
}
''', [0, 6, 12]),
    "angular-velocities": (PROTO + '''
def PointInstancer "PI" {
    rel prototypes = [</Protos/A>]
    int[] protoIndices = [0, 0]
    point3f[] positions = [(0,0,0), (1,0,0)]
    quatf[] orientationsf.timeSamples = {0: [(1,0,0,0), (0.5,0.5,0.5,0.5)]}
    vector3f[] angularVelocities.timeSamples = {0: [(0,0,90), (45,0,0)]}
    vector3f[] accelerations = [(1,0,0), (0,0,0)]
}
''', [0, 6, 24, 47]),
    "accelerations": (PROTO + '''
def PointInstancer "PI" {
    rel prototypes = [</Protos/A>]
    int[] protoIndices = [0]
    point3f[] positions.timeSamples = {0: [(0,0,0)]}
    vector3f[] velocities.timeSamples = {0: [(1,2,0)]}
    vector3f[] accelerations.timeSamples = {0: [(0,-9.8,0)]}
}
''', [0, 12, 48]),
}


def oracle(stage, time):
    rows = {}
    for prim in stage.Traverse():
        if not prim.IsA(UsdGeom.PointInstancer):
            continue
        pi = UsdGeom.PointInstancer(prim)
        xforms = pi.ComputeInstanceTransformsAtTime(
            time, time, UsdGeom.PointInstancer.ExcludeProtoXform,
            UsdGeom.PointInstancer.IgnoreMask)
        mask = list(pi.ComputeMaskAtTime(time)) or [True] * len(xforms)
        rows[str(prim.GetPath())] = (
            [1 if m else 0 for m in mask],
            [float(v) for m in xforms for r in range(4) for v in m.GetRow(r)])
    return rows


def native(tool, path, time):
    run = subprocess.run([str(tool), "--dump-instancer", str(path), repr(time)],
                         check=True, capture_output=True, text=True, timeout=30)
    rows = {}
    for line in run.stdout.splitlines():
        parts = line.split()
        n = int(parts[1])
        rows[parts[0]] = ([int(v) for v in parts[2:2 + n]],
                          [float(v) for v in parts[2 + n:]])
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lusdcat", type=Path, required=True)
    parser.add_argument("--geom-compare", type=Path, required=True)
    parser.add_argument("--tolerance", type=float, default=1e-5)
    args = parser.parse_args()
    failures = []
    checked = 0
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        for case, (body, times, *tol) in SCENES.items():
            tolerance = tol[0] if tol else args.tolerance
            source = folder / f"{case}.usda"
            source.write_text(HEAD + body)
            crate = source.with_suffix(".usdc")
            subprocess.run([str(args.lusdcat.resolve()), "--rewrite-layer",
                            "--output-format", "usdc", "-o", str(crate), str(source)],
                           check=True, capture_output=True, timeout=30)
            stage = Usd.Stage.Open(str(source))
            for time in times:
                expected = oracle(stage, time)
                for path in (source, crate):
                    got = native(args.geom_compare.resolve(), path, time)
                    label = f"{case}{path.suffix}@{time}"
                    if set(got) != set(expected):
                        failures.append(f"{label}: prims {sorted(got)} != {sorted(expected)}")
                        continue
                    for prim, (mask, mats) in expected.items():
                        gmask, gmats = got[prim]
                        if gmask != mask:
                            failures.append(f"{label} {prim}: mask {gmask} != {mask}")
                        if len(gmats) != len(mats) or not all(
                                math.isclose(a, b, abs_tol=tolerance, rel_tol=0)
                                for a, b in zip(gmats, mats)):
                            bad = [i for i, (a, b) in enumerate(zip(gmats, mats))
                                   if not math.isclose(a, b, abs_tol=tolerance, rel_tol=0)]
                            first = bad[0] if bad else min(len(gmats), len(mats))
                            failures.append(
                                f"{label} {prim}: {len(bad)} transform entries differ; "
                                f"instance {first // 16} entry {first % 16}: "
                                f"LightUSD {gmats[first // 16 * 16:first // 16 * 16 + 16]} "
                                f"OpenUSD {mats[first // 16 * 16:first // 16 * 16 + 16]}")
                    checked += 1
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"{checked} PointInstancer runtime samples agree in OpenUSD and LightUSD "
          f"({len(SCENES)} scenes, USDA and USDC)")


if __name__ == "__main__":
    main()

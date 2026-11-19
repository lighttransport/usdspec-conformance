#!/usr/bin/env python3
"""Compare usdLod heuristics in OpenUSD and LightUSD.

UsdLod.DistanceHeuristic.CreateDistanceHeuristicQuery (center, bounding
volume extent, thresholds, blend thresholds) -> ComputeDistance (with and
without hysteresis) and ComputeLOD, and UsdLod.OverrideAPI.ComputeLODOverride
(nested and inherited modes, indexedLOD), against `geom_compare --dump-lod`
over several viewpoints and transforms, on USDA and flattened USDC.
"""
import argparse
import math
from pathlib import Path
import subprocess
import tempfile

from pxr import Gf, Usd, UsdLod

SCENE = '''#usda 1.0
def Xform "World" (
    prepend apiSchemas = ["LODOverrideAPI"]
) {
    uniform token lod:override:mode = "inherited"
    def Cube "Volume" {
        double size = 4
    }
    def Sphere "Authored" {
        float3[] extent = [(-1, -2, -3), (1, 2, 3)]
    }
    def LODDistanceHeuristic "CenterOnly" {
        uniform token lod:domain = "geometry"
        point3f center = (1, 0, 0)
        float[] thresholds = [5, 10, 20]
    }
    def LODDistanceHeuristic "Boxed" {
        uniform token lod:domain = "geometry"
        rel boundingVolume = [</World/Volume>]
        float[] thresholds = [3, 8, 15]
        float[] blendThresholds = [4, 10, 18]
    }
    def LODDistanceHeuristic "AuthoredExtent" {
        rel boundingVolume = [</World/Missing>, </World/Authored>]
        float[] thresholds = [1, 2, 4, 8]
        float[] blendThresholds = [1.5, 3, 4, 9]
    }
    def Xform "Forced" (
        prepend apiSchemas = ["LODOverrideAPI"]
    ) {
        uniform token lod:override:mode = "indexedLOD"
        float lod:override:index = 2.5
        def Xform "Child" (
            prepend apiSchemas = ["LODOverrideAPI"]
        ) {
            uniform token lod:override:mode = "inherited"
        }
        def Xform "Highest" (
            prepend apiSchemas = ["LODOverrideAPI"]
        ) {
            uniform token lod:override:mode = "highestLOD"
        }
    }
}
'''
VIEWS = [(0, 0, 0), (7, 0, 0), (0, 12, 0), (3, 3, 3), (-25, 4, 1), (1.2, 0.5, 0.1)]
MATRICES = [
    [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
    [2, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 3, -1, 2, 1],
]
PREV, HYST = 9.0, 1.5


def oracle(stage, view, matrix):
    rows = {}
    m = Gf.Matrix4d(*matrix)
    v = Gf.Vec3d(*view)
    for prim in stage.Traverse():
        path = str(prim.GetPath())
        if prim.GetTypeName() == "LODDistanceHeuristic":
            q = UsdLod.DistanceHeuristic(prim).CreateDistanceHeuristicQuery(Usd.TimeCode.Default())
            d = q.ComputeDistance(v, m)
            dh = q.ComputeDistance(v, m, PREV, HYST)
            rows[f"{path} dist"] = (d, q.ComputeLOD(d), dh, q.ComputeLOD(dh), str(q.lodDomain) or "-")
        result = UsdLod.OverrideAPI(prim).ComputeLODOverride() if prim.HasAPI(UsdLod.OverrideAPI) \
            else None
        rows[f"{path} override"] = result
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lusdcat", type=Path, required=True)
    parser.add_argument("--geom-compare", type=Path, required=True)
    args = parser.parse_args()
    failures, checked = [], 0
    with tempfile.TemporaryDirectory() as tmp:
        scene = Path(tmp) / "lod.usda"
        scene.write_text(SCENE)
        flat = Path(tmp) / "lod.usdc"
        subprocess.run([str(args.lusdcat.resolve()), "-f", "--output-format", "usdc",
                        "-o", str(flat), str(scene)], check=True, capture_output=True, timeout=30)
        stage = Usd.Stage.Open(str(scene))
        for view in VIEWS:
            for matrix in MATRICES:
                expected = oracle(stage, view, matrix)
                for path in (scene, flat):
                    out = subprocess.run(
                        [str(args.geom_compare.resolve()), "--dump-lod", str(path), "0",
                         *map(repr, view), *map(repr, matrix), repr(PREV), repr(HYST)],
                        check=True, capture_output=True, text=True, timeout=30).stdout
                    got = {}
                    for line in out.splitlines():
                        parts = line.split()
                        if parts[1] == "dist":
                            got[f"{parts[0]} dist"] = (float(parts[2]), float(parts[4]),
                                                       float(parts[6]), float(parts[8]), parts[10])
                        else:
                            got[f"{parts[0]} override"] = (parts[2], float(parts[3]))
                    for key, want in expected.items():
                        have = got.get(key)
                        if key.endswith("dist"):
                            ok = have is not None and have[4] == want[4] and all(
                                math.isclose(a, b, rel_tol=1e-5, abs_tol=1e-5)
                                for a, b in zip(have[:4], want[:4]))
                        elif want is None:
                            continue
                        else:
                            mode, index = want if isinstance(want, tuple) else (want, 0.0)
                            ok = have is not None and have[0] == str(mode) and (
                                str(mode) != "indexedLOD" or math.isclose(have[1], index))
                        if not ok:
                            failures.append(f"{path.suffix} view={view} M#{MATRICES.index(matrix)} "
                                            f"{key}: LightUSD {have} OpenUSD {want}")
                        checked += 1
    if failures:
        raise SystemExit("\n".join(failures[:20]))
    print(f"{checked} usdLod distance/LOD/override results agree in OpenUSD and LightUSD")


if __name__ == "__main__":
    main()

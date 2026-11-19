#!/usr/bin/env python3
"""Compare linear blend skinning in Lean, OpenUSD, and LightUSD."""
import argparse
import json
import math
from pathlib import Path
import subprocess
import tempfile

from pxr import Gf, Usd, UsdGeom, UsdSkel


SCENE = """#usda 1.0
def SkelRoot "Model" {
    def Skeleton "Rig" (prepend apiSchemas = ["SkelBindingAPI"]) {
        uniform token[] joints = ["root", "root/child"]
        uniform matrix4d[] bindTransforms = [IDENTITY, IDENTITY]
        uniform matrix4d[] restTransforms = [IDENTITY, IDENTITY]
        rel skel:animationSource = </Model/Motion>
    }
    def SkelAnimation "Motion" {
        uniform token[] joints = ["root", "root/child"]
        float3[] translations.timeSamples = {0: [(0,0,0),(0,0,0)], 2: [(4,0,0),(4,0,0)]}
        quatf[] rotations = [(1,0,0,0),(1,0,0,0)]
        half3[] scales = [(1,1,1),(1,1,1)]
    }
    def Mesh "Mesh" (prepend apiSchemas = ["SkelBindingAPI"]) {
        rel skel:skeleton = </Model/Rig>
        point3f[] points = [(0,0,0),(1,0,0),(0,1,0)]
        int[] faceVertexCounts = [3]
        int[] faceVertexIndices = [0,1,2]
        int[] primvars:skel:jointIndices = [0,1,0,1,0,1] (
            elementSize = 2
            interpolation = "vertex"
        )
        float[] primvars:skel:jointWeights = [0.25,0.75,1,0,0,1] (
            elementSize = 2
            interpolation = "vertex"
        )
    }
}
""".replace("IDENTITY", "((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1))")


def verify(actual, expected, label):
    if len(actual) != len(expected) or not all(
            math.isclose(a, b, abs_tol=1e-6, rel_tol=0) for a, b in zip(actual, expected)):
        raise AssertionError(f"{label}: expected {expected}, got {actual}")


def replay(folder, case, text, probes, args):
    source = folder / f"{case}.usda"
    source.write_text(text)
    crate = source.with_suffix(".usdc")
    subprocess.run([str(args.lusdcat.resolve()), "--rewrite-layer",
                    "--output-format", "usdc", "-o", str(crate), str(source)],
                   check=True, capture_output=True, timeout=30)
    stage = Usd.Stage.Open(str(source))
    stage.SetEditTarget(stage.GetSessionLayer())
    times = [probe["time"] for probe in probes]
    if not UsdSkel.BakeSkinning(stage.Traverse(), Gf.Interval(min(times), max(times))):
        raise AssertionError("OpenUSD skinning bake failed")
    mesh = UsdGeom.Mesh.Get(stage, "/Model/Mesh")
    for probe in probes:
        time = probe["time"]
        expected = [n / d for n, d in probe[case]]
        verify([c for p in mesh.GetPointsAttr().Get(time) for c in p],
               expected, f"OpenUSD at {time}")
        for path in (source, crate):
            run = subprocess.run([str(args.skin_compare.resolve()), "--dump", str(path), str(time)],
                                 check=True, capture_output=True, text=True, timeout=30)
            rows = [line.split() for line in run.stdout.splitlines()
                    if line.startswith("/Model/Mesh ")]
            if len(rows) != 1 or int(rows[0][1]) != len(expected):
                raise AssertionError(f"{path.name} at {time}: missing mesh output")
            verify([float(value) for value in rows[0][2:]], expected,
                   f"LightUSD {path.suffix} at {time}")


def check_dual_quaternion_oracle(folder, probe):
    text = SCENE.replace(
        "rotations = [(1,0,0,0),(1,0,0,0)]",
        "rotations = [(1,0,0,0),(0,0,0,1)]").replace(
        "points = [(0,0,0),(1,0,0),(0,1,0)]",
        "points = [(1,0,0),(1,0,0),(0,1,0)]")
    for method in ("classicLinear", "dualQuaternion"):
        source = folder / f"{method}.usda"
        source.write_text(text.replace(
            'rel skel:skeleton = </Model/Rig>',
            f'rel skel:skeleton = </Model/Rig>\n'
            f'        uniform token primvars:skel:skinningMethod = "{method}"'))
        stage = Usd.Stage.Open(str(source))
        stage.SetEditTarget(stage.GetSessionLayer())
        if not UsdSkel.BakeSkinning(stage.Traverse(), Gf.Interval(0, 2)):
            raise AssertionError(f"OpenUSD {method} bake failed")
        mesh = UsdGeom.Mesh.Get(stage, "/Model/Mesh")
        expected = ([n / d for n, d in probe["dualQuaternionProbe"]]
                    if method == "dualQuaternion" else [-0.5, 0, 0])
        verify(mesh.GetPointsAttr().Get(0)[0], expected, method)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skin-compare", type=Path, required=True)
    parser.add_argument("--lusdcat", type=Path, required=True)
    args = parser.parse_args()
    vectors = Path(__file__).with_name("generated") / "lean/domain-skeleton-deformation-vectors.json"
    probes = json.loads(vectors.read_text())
    assert probes, "missing deformation cases"
    with tempfile.TemporaryDirectory(prefix="domain-skeleton-deformation-") as tmp:
        diagonal = SCENE.replace(
            "rotations = [(1,0,0,0),(1,0,0,0)]",
            "rotations = [(0,0,0,1),(1,0,0,0)]").replace(
            "scales = [(1,1,1),(1,1,1)]", "scales = [(2,3,1),(1,1,1)]")
        rotated = diagonal.replace("rotations = [(0,0,0,1)", "rotations = [(0.6,0,0,0.8)")
        cases = (("translation", SCENE), ("diagonal", diagonal), ("rotated", rotated))
        for case, text in cases:
            replay(Path(tmp), case, text, probes, args)
        check_dual_quaternion_oracle(Path(tmp), probes[0])
    print(f"{len(cases) * len(probes)} animated deformation samples agree in Lean, OpenUSD, and LightUSD")


if __name__ == "__main__":
    main()

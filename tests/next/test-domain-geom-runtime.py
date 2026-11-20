#!/usr/bin/env python3
"""Compare PointInstancer runtime evaluation in OpenUSD and LightUSD.

For each scene, at each sampled time, compare per-instance transforms
(UsdGeom.PointInstancer.ComputeInstanceTransformsAtTime, ExcludeProtoXform)
and visibility masks (ComputeMaskAtTime) against `geom_compare
--dump-instancer`. The authored USDA and a LightUSD-written USDC copy are both
replayed through the native side.
"""
import argparse
import json
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


XFORM_SCENES = {
    "op-order": ('''
def Xform "A" {
    double3 xformOp:translate = (1, 2, 3)
    float3 xformOp:rotateXYZ = (30, 45, 60)
    float3 xformOp:scale = (2, 1, 0.5)
    uniform token[] xformOpOrder = ["xformOp:translate", "xformOp:rotateXYZ", "xformOp:scale"]
    def Xform "B" {
        float3 xformOp:rotateZYX = (10, 20, 30)
        quatf xformOp:orient = (0.5, 0.5, 0.5, 0.5)
        uniform token[] xformOpOrder = ["xformOp:orient", "xformOp:rotateZYX"]
        def Scope "S" {
            def Cube "C" {
                double3 xformOp:translate:pivot = (0, 1, 0)
                float xformOp:rotateY = 90
                uniform token[] xformOpOrder = ["xformOp:translate:pivot", "xformOp:rotateY", "!invert!xformOp:translate:pivot"]
            }
        }
    }
}
''', [0]),
    "reset-and-matrix": ('''
def Xform "P" {
    double3 xformOp:translate = (5, 0, 0)
    uniform token[] xformOpOrder = ["xformOp:translate"]
    def Xform "Reset" {
        matrix4d xformOp:transform = ((1,0,0,0),(0,0,1,0),(0,-1,0,0),(1,2,3,1))
        uniform token[] xformOpOrder = ["!resetXformStack!", "xformOp:transform"]
        def Xform "Child" {
            float xformOp:rotateX.timeSamples = {0: 0, 10: 90}
            uniform token[] xformOpOrder = ["xformOp:rotateX"]
        }
    }
    def Xform "Unordered" {
        double3 xformOp:translate = (9, 9, 9)
    }
}
''', [0, 2.5, 10]),
}


EXTENT_SCENE = ('''
def Xform "W" {
    def Mesh "Mesh" {
        point3f[] points.timeSamples = {0: [(0,0,0),(1,2,3),(-1,0.5,0)], 10: [(0,0,0),(3,2,1),(0,-4,0)]}
        int[] faceVertexCounts = [3]
        int[] faceVertexIndices = [0,1,2]
    }
    def Points "PerPoint" {
        point3f[] points = [(0,0,0),(2,0,0)]
        float[] widths = [0.5, 1]
    }
    def Points "NoWidths" {
        point3f[] points = [(0,0,0),(2,1,0)]
    }
    def Points "ConstantWidth" {
        point3f[] points = [(0,0,0),(2,0,0)]
        float[] widths = [1] (interpolation = "constant")
    }
    def BasisCurves "Curves" {
        uniform token type = "cubic"
        int[] curveVertexCounts = [4]
        point3f[] points = [(0,0,0),(1,1,0),(2,1,0),(3,0,0)]
        float[] widths = [0.1, 0.4, 0.2, 0.1]
    }
    def Cube "CubeDefault" {}
    def Cube "Cube" {
        double size = 3
    }
    def Sphere "Sphere" {
        double radius = 0.25
    }
    def Cylinder "Cylinder" {
        double height = 4
        double radius = 0.5
        uniform token axis = "X"
    }
    def Cone "Cone" {
        uniform token axis = "Y"
    }
    def Capsule "Capsule" {
        double height = 2
        double radius = 0.3
    }
    def Cylinder_1 "Cyl1" {
        double radiusTop = 0.2
        double radiusBottom = 0.7
        double height = 1
    }
    def Capsule_1 "Cap1" {
        double radiusTop = 0.2
        double radiusBottom = 0.6
        double height = 2
        uniform token axis = "X"
    }
    def Plane "Plane" {
        double width = 4
        double length = 1
        uniform token axis = "X"
    }
    def Plane "PlaneY" {
        uniform token axis = "Y"
        double length = 3
    }
    def SphereLight "SphereLightDefault" {}
    def SphereLight "SphereLightPoint" {
        float inputs:radius = 2
        bool treatAsPoint = true
    }
    def CylinderLight "CylinderLight" {
        float inputs:length = 4
        float inputs:radius = 0.25
        bool treatAsLine = true
    }
    def DiskLight "DiskLight" {
        float inputs:radius = 3
    }
    def RectLight "RectLight" {
        float inputs:width = 2
        float inputs:height = 6
    }
    def PortalLight "PortalLight" {}
}
''', [0, 5])


def extent_oracle(stage, time):
    rows = {}
    for prim in stage.Traverse():
        if not prim.IsA(UsdGeom.Boundable) or prim.IsA(UsdGeom.PointInstancer):
            continue
        extent = UsdGeom.Boundable.ComputeExtentFromPlugins(UsdGeom.Boundable(prim), time)
        if extent is not None and len(extent) == 2:
            rows[str(prim.GetPath())] = [float(v) for corner in extent for v in corner]
        else:
            rows[str(prim.GetPath())] = None
    return rows


def extent_native(tool, path, time):
    run = subprocess.run([str(tool), "--dump-extent", str(path), repr(time)],
                         check=True, capture_output=True, text=True, timeout=30)
    return {parts[0]: [float(v) for v in parts[1:]]
            for parts in (line.split() for line in run.stdout.splitlines())}


VECTORS = Path(__file__).resolve().parent / "generated/lean/domain-geom-runtime-vectors.json"


def rat(values):
    return [n / d for n, d in values]


def fmt(values):
    return ", ".join(repr(v) for v in values)


def lean_scenes(vectors):
    """USDA scenes and expected values derived from the Lean vectors."""
    lines = [PROTO]
    expected_instances = []
    for i, inst in enumerate(vectors["instances"]):
        t, q, sc = rat(inst["translate"]), rat(inst["orient"]), rat(inst["scale"])
        lines.append(f'''def PointInstancer "LeanPI{i}" {{
    rel prototypes = [</Protos/A>]
    int[] protoIndices = [0]
    point3f[] positions = [({fmt(t)})]
    quatf[] orientationsf = [({fmt(q)})]
    float3[] scales = [({fmt(sc)})]
}}
''')
        expected_instances.append((f"/LeanPI{i}", rat(inst["matrix"])))
    expected_extents = {}
    for i, shape in enumerate(vectors["shapes"]):
        body = "".join(f"    {line}\n" for line in shape["body"].split("\n") if line)
        lines.append(f'def {shape["type"]} "LeanShape{i}" {{\n{body}}}\n')
        expected_extents[f"/LeanShape{i}"] = rat(shape["extent"])
    pts = rat(vectors["pointsPositions"])
    point_text = f"({fmt(pts[0:3])}), ({fmt(pts[3:6])})"
    for i, case in enumerate(vectors["points"]):
        widths = ""
        if case["widths"]:
            widths = (f'    float[] widths = [{fmt(rat(case["widths"]))}] '
                      f'(interpolation = "{case["interpolation"]}")\n')
        lines.append(f'def Points "LeanPoints{i}" {{\n    point3f[] points = [{point_text}]\n'
                     f'{widths}}}\n')
        expected_extents[f"/LeanPoints{i}"] = (
            rat(case["openusd"]) if case["openusd"] is not None else None)
    curve = vectors["curve"]
    cp = rat(curve["points"])
    lines.append('def BasisCurves "LeanCurve" {\n    uniform token type = "cubic"\n'
                 '    int[] curveVertexCounts = [4]\n'
                 f'    point3f[] points = [{", ".join("(" + fmt(cp[k:k + 3]) + ")" for k in range(0, len(cp), 3))}]\n'
                 f'    float[] widths = [{fmt(rat(curve["widths"]))}]\n}}\n')
    expected_extents["/LeanCurve"] = rat(curve["extent"])
    motion = []
    for i, m in enumerate(vectors["motion"]):
        (p,), (v,), (a,), (dt,) = (rat(m[k]) for k in ("position", "velocity", "acceleration", "dt"))
        lines.append(f'''def PointInstancer "LeanMotion{i}" {{
    rel prototypes = [</Protos/A>]
    int[] protoIndices = [0]
    point3f[] positions.timeSamples = {{0: [({p!r}, 0, 0)]}}
    vector3f[] velocities.timeSamples = {{0: [({v!r}, 0, 0)]}}
    vector3f[] accelerations.timeSamples = {{0: [({a!r}, 0, 0)]}}
}}
''')
        motion.append((f"/LeanMotion{i}", dt * 24, rat(m["result"])[0]))
    return "".join(lines), expected_instances, expected_extents, motion


def close(a, b, tol):
    return len(a) == len(b) and all(math.isclose(x, y, abs_tol=tol, rel_tol=0)
                                    for x, y in zip(a, b))


def check_lean(folder, args, failures):
    vectors = json.loads(VECTORS.read_text())
    text, instances, extents, motion = lean_scenes(vectors)
    source = folder / "lean.usda"
    source.write_text(HEAD + text)
    crate = source.with_suffix(".usdc")
    subprocess.run([str(args.lusdcat.resolve()), "--rewrite-layer",
                    "--output-format", "usdc", "-o", str(crate), str(source)],
                   check=True, capture_output=True, timeout=30)
    stage = Usd.Stage.Open(str(source))
    tool = args.geom_compare.resolve()
    checked = 0
    pxr_inst = oracle(stage, 0)
    pxr_ext = extent_oracle(stage, 0)
    for path in (source, crate):
        got_inst = native(tool, path, 0)
        got_ext = extent_native(tool, path, 0)
        for prim, matrix in instances:
            for who, rows in (("OpenUSD", pxr_inst), ("LightUSD" + path.suffix, got_inst)):
                if prim not in rows or not close(rows[prim][1], matrix, 1e-6):
                    failures.append(f"Lean {prim}: {who} {rows.get(prim)} != {matrix}")
            checked += 1
        for prim, box in extents.items():
            for who, value in (("OpenUSD", pxr_ext.get(prim)),
                               ("LightUSD" + path.suffix, got_ext.get(prim))):
                if (box is None) != (value is None) or (box is not None and not close(value, box, 1e-6)):
                    failures.append(f"Lean {prim} extent: {who} {value} != {box}")
            checked += 1
        for prim, time, x in motion:
            got = native(tool, path, time).get(prim)
            pxr = oracle(stage, time).get(prim)
            for who, row in (("OpenUSD", pxr), ("LightUSD" + path.suffix, got)):
                if row is None or not math.isclose(row[1][12], x, abs_tol=1e-5, rel_tol=0):
                    failures.append(f"Lean {prim}@{time}: {who} x {row and row[1][12]} != {x}")
            checked += 1
    return checked


def xform_oracle(stage, time):
    cache = UsdGeom.XformCache(time)
    rows = {}
    for prim in stage.Traverse():
        if prim.IsA(UsdGeom.Xformable):
            m = cache.GetLocalToWorldTransform(prim)
            rows[str(prim.GetPath())] = [float(v) for r in range(4) for v in m.GetRow(r)]
    return rows


def xform_native(tool, path, time):
    run = subprocess.run([str(tool), "--dump-xform", str(path), repr(time)],
                         check=True, capture_output=True, text=True, timeout=30)
    return {parts[0]: [float(v) for v in parts[1:]]
            for parts in (line.split() for line in run.stdout.splitlines())}


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
    xform_checked = 0
    extent_checked = 0
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
        for case, (body, times) in XFORM_SCENES.items():
            source = folder / f"xform-{case}.usda"
            source.write_text(HEAD + body)
            crate = source.with_suffix(".usdc")
            subprocess.run([str(args.lusdcat.resolve()), "--rewrite-layer",
                            "--output-format", "usdc", "-o", str(crate), str(source)],
                           check=True, capture_output=True, timeout=30)
            stage = Usd.Stage.Open(str(source))
            for time in times:
                expected = xform_oracle(stage, time)
                for path in (source, crate):
                    got = xform_native(args.geom_compare.resolve(), path, time)
                    label = f"xform-{case}{path.suffix}@{time}"
                    for prim, mat in expected.items():
                        if prim not in got:
                            failures.append(f"{label} {prim}: no LightUSD transform")
                        elif not all(math.isclose(a, b, abs_tol=args.tolerance, rel_tol=0)
                                     for a, b in zip(got[prim], mat)):
                            failures.append(f"{label} {prim}: LightUSD {got[prim]} "
                                            f"OpenUSD {mat}")
                        else:
                            xform_checked += 1
        lean_checked = check_lean(folder, args, failures)
        source = folder / "extent.usda"
        source.write_text(HEAD + EXTENT_SCENE[0])
        crate = source.with_suffix(".usdc")
        subprocess.run([str(args.lusdcat.resolve()), "--rewrite-layer",
                        "--output-format", "usdc", "-o", str(crate), str(source)],
                       check=True, capture_output=True, timeout=30)
        stage = Usd.Stage.Open(str(source))
        for time in EXTENT_SCENE[1]:
            expected = extent_oracle(stage, time)
            for path in (source, crate):
                got = extent_native(args.geom_compare.resolve(), path, time)
                label = f"extent{path.suffix}@{time}"
                for prim, box in expected.items():
                    mine = got.get(prim)
                    if box is None or mine is None:
                        if box is not mine:
                            failures.append(f"{label} {prim}: LightUSD {mine} OpenUSD {box}")
                        else:
                            extent_checked += 1
                    elif not all(math.isclose(a, b, abs_tol=1e-6, rel_tol=0)
                                 for a, b in zip(mine, box)):
                        failures.append(f"{label} {prim}: LightUSD {mine} OpenUSD {box}")
                    else:
                        extent_checked += 1
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"{checked} PointInstancer runtime samples agree in OpenUSD and LightUSD "
          f"({len(SCENES)} scenes, USDA and USDC); {xform_checked} local-to-world "
          f"transforms agree with UsdGeom.XformCache; {extent_checked} computed "
          f"extents agree with ComputeExtentFromPlugins; {lean_checked} Lean runtime "
          f"vectors agree with both")


if __name__ == "__main__":
    main()

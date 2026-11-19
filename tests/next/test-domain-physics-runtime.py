#!/usr/bin/env python3
"""Compare resolved UsdPhysics objects in OpenUSD and LightUSD.

OpenUSD UsdPhysics.LoadUsdPhysicsFromRange (the reference parser) against
`geom_compare --dump-physics` (lightusd::ResolvePhysics) on the scenes in
physics-runtime/: scene gravity defaults (upAxis, metersPerUnit), rigid-body
and collider ownership (enabled-body resolution, simulation owners),
joint body resolution and flags, and collision-group merging. Scenes are
replayed from USDA and a LightUSD-written flattened USDC.

`invertFilteredGroups` is compared only where the representative group
authors it: OpenUSD leaves the descriptor field uninitialized otherwise
(issues/OpenUSD/14).
"""
import argparse
import json
import math
from pathlib import Path
import subprocess
import tempfile
import warnings

from pxr import Usd, UsdPhysics

SCENES = Path(__file__).resolve().parent / "physics-runtime"
JOINTS = {"FixedJoint", "RevoluteJoint", "PrismaticJoint", "SphericalJoint",
          "DistanceJoint", "CustomJoint", "D6Joint"}
SHAPES = ("Shape",)


def paths(values):
    return sorted(str(p) for p in values)


def oracle(stage):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        result = UsdPhysics.LoadUsdPhysicsFromRange(stage, ["/"])
    out = {}
    for kind, (prim_paths, descs) in result.items():
        name = str(kind).split(".")[-1]
        for path, d in zip(prim_paths, descs):
            path = str(path)
            if name == "Scene":
                out[path] = {"kind": "Scene", "gravityDirection": list(d.gravityDirection),
                             "gravityMagnitude": d.gravityMagnitude}
            elif name == "RigidBody":
                out[path] = {"kind": "RigidBody", "rigidBodyEnabled": d.rigidBodyEnabled,
                             "simulationOwners": paths(d.simulationOwners),
                             "collisions": paths(d.collisions)}
            elif name.endswith(SHAPES):
                out[path] = {"kind": "Collider", "rigidBody": str(d.rigidBody) if d.rigidBody else "",
                             "collisionEnabled": d.collisionEnabled,
                             "simulationOwners": paths(d.simulationOwners)}
            elif name in JOINTS:
                out[path] = {"kind": "Joint",
                             **{k: str(getattr(d, k)) if getattr(d, k) else ""
                                for k in ("rel0", "rel1", "body0", "body1")},
                             "jointEnabled": d.jointEnabled, "collisionEnabled": d.collisionEnabled,
                             "excludeFromArticulation": d.excludeFromArticulation}
            elif name == "CollisionGroup":
                prim = stage.GetPrimAtPath(path)
                authored = prim.GetAttribute("physics:invertFilteredGroups").HasAuthoredValue()
                out[path] = {"kind": "CollisionGroup", "filteredGroups": paths(d.filteredGroups),
                             "mergedGroups": paths(d.mergedGroups)}
                if authored:
                    out[path]["invertFilteredGroups"] = d.invertFilteredGroups
    return out


def native(tool, path):
    run = subprocess.run([str(tool), "--dump-physics", str(path)], check=True,
                         capture_output=True, text=True, timeout=30)
    out = {}
    for line in run.stdout.splitlines():
        row = json.loads(line)
        path = row.pop("path")
        for key in ("simulationOwners", "collisions", "filteredGroups", "mergedGroups"):
            if key in row:
                row[key] = sorted(row[key])
        out[path] = row
    return out


def same(a, b):
    if isinstance(a, float) or isinstance(b, float):
        return math.isclose(a, b, rel_tol=1e-6, abs_tol=1e-6)
    if isinstance(a, list) and a and isinstance(a[0], (int, float)):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    return a == b


VECTORS = Path(__file__).resolve().parent / "generated/lean/domain-physics-resolve-vectors.json"


def lean_scenes(vectors):
    """(usda text, {path: expected fields}) per Lean vector."""
    scenes = []
    for i, g in enumerate(vectors["gravity"]):
        (n, d), = g["metersPerUnit"]
        mag = g["authoredMagnitude"]
        body = (f"    float physics:gravityMagnitude = {mag[0][0] / mag[0][1]!r}\n" if mag else "")
        text = (f'#usda 1.0\n(\n    upAxis = "{g["upAxis"]}"\n    metersPerUnit = {n / d!r}\n)\n'
                f'def PhysicsScene "S" {{\n{body}}}\n')
        scenes.append((f"lean-gravity-{i}", text, {"/S": {
            "gravityMagnitude": g["magnitude"][0][0] / g["magnitude"][0][1],
            "gravityDirection": [a / b for a, b in g["direction"]]}}))
    for i, c in enumerate(vectors["chains"]):
        chain = list(reversed(c["chain"]))  # root first
        lines, indent = ["#usda 1.0"], ""
        for prim in chain:
            apis = []
            if prim["enabledBody"] or prim["disabledBody"]:
                apis.append("PhysicsRigidBodyAPI")
            if prim["collision"]:
                apis.append("PhysicsCollisionAPI")
            meta = (f' (prepend apiSchemas = [{", ".join(chr(34) + a + chr(34) for a in apis)}])'
                    if apis else "")
            kind = "Cube" if prim["collision"] else "Xform"
            lines.append(f'{indent}def {kind} "{prim["path"].rsplit("/", 1)[1]}"{meta} {{')
            if prim["disabledBody"]:
                lines.append(f"{indent}    bool physics:rigidBodyEnabled = 0")
            indent += "    "
        for _ in chain:
            indent = indent[:-4]
            lines.append(f"{indent}}}")
        leaf = c["chain"][0]["path"]
        lines.append(f'def PhysicsFixedJoint "J" {{\n    rel physics:body0 = <{leaf}>\n}}')
        expected = {"/J": {"body0": c["jointBody"]}}
        if c["chain"][0]["collision"]:
            expected[leaf] = {"rigidBody": c["colliderBody"]}
        scenes.append((f"lean-chain-{i}", "\n".join(lines) + "\n", expected))
    return scenes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lusdcat", type=Path, required=True)
    parser.add_argument("--geom-compare", type=Path, required=True)
    args = parser.parse_args()
    failures, checked = [], 0
    with tempfile.TemporaryDirectory() as tmp:
        for scene in sorted(SCENES.glob("*.usda")):
            crate = Path(tmp) / (scene.stem + ".usdc")
            subprocess.run([str(args.lusdcat.resolve()), "-f", "--output-format", "usdc",
                            "-o", str(crate), str(scene)], check=True, capture_output=True,
                           timeout=30)
            expected = oracle(Usd.Stage.Open(str(scene)))
            for path in (scene, crate):
                got = native(args.geom_compare.resolve(), path)
                if set(got) != set(expected):
                    failures.append(f"{path.name}: objects {sorted(set(got) ^ set(expected))} differ")
                for prim, want in expected.items():
                    have = got.get(prim, {})
                    for key, value in want.items():
                        if not same(have.get(key), value):
                            failures.append(f"{path.name} {prim} {key}: LightUSD "
                                            f"{have.get(key)!r} OpenUSD {value!r}")
                        checked += 1
        lean_checked = 0
        known_gaps = 0
        for name, text, expected in lean_scenes(json.loads(VECTORS.read_text())):
            scene = Path(tmp) / f"{name}.usda"
            scene.write_text(text)
            pxr = oracle(Usd.Stage.Open(str(scene)))
            mine = native(args.geom_compare.resolve(), scene)
            for prim, fields in expected.items():
                for key, value in fields.items():
                    for who, rows in (("OpenUSD", pxr), ("LightUSD", mine)):
                        have = rows.get(prim, {}).get(key)
                        # issues/OpenUSD/15: OpenUSD keeps an authored negative
                        # magnitude instead of substituting earth gravity.
                        if (who == "OpenUSD" and key == "gravityMagnitude" and
                                have is not None and have < 0 and value > 0):
                            known_gaps += 1
                            continue
                        if not same(have, value):
                            failures.append(f"Lean {name} {prim} {key}: {who} {have!r} != {value!r}")
                    lean_checked += 1
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"{checked} resolved physics fields agree in OpenUSD and LightUSD "
          f"({len(list(SCENES.glob('*.usda')))} scenes, USDA and flattened USDC); "
          f"{lean_checked} Lean PhysicsResolve vectors agree with both "
          f"({known_gaps} known OpenUSD gap, issues/OpenUSD/15)")


if __name__ == "__main__":
    main()

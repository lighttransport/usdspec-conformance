#!/usr/bin/env python3
"""Compare usdSemantics label queries in OpenUSD and LightUSD.

UsdSemantics.LabelsAPI.ComputeInheritedTaxonomies and
UsdSemantics.LabelsQuery (ComputeUniqueDirectLabels and
ComputeUniqueInheritedLabels, at a time code and over a GfInterval) against
`geom_compare --dump-semantics`, on authored USDA and LightUSD-written USDC,
including composition through a reference.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

from pxr import Gf, Usd, UsdSemantics

ASSET = '''#usda 1.0
def Xform "Car" (
    prepend apiSchemas = ["SemanticsLabelsAPI:category"]
) {
    token[] semantics:labels:category = ["vehicle"]
    def Mesh "Wheel" (
        prepend apiSchemas = ["SemanticsLabelsAPI:category", "SemanticsLabelsAPI:state"]
    ) {
        token[] semantics:labels:category = ["wheel", "vehicle"]
        token[] semantics:labels:state.timeSamples = {0: ["still"], 10: ["spinning"], 20: ["broken", "still"]}
    }
}
'''
SCENE = '''#usda 1.0
def Xform "World" (
    prepend apiSchemas = ["SemanticsLabelsAPI:style"]
) {
    token[] semantics:labels:style = ["toy"]
    def "Car" (
        references = @./asset.usda@</Car>
    ) {
        over "Wheel" {
            token[] semantics:labels:category = ["tire"]
        }
        def Mesh "Body" {}
    }
}
'''
TAXONOMIES = ["category", "state", "style"]
QUERIES = [(0, None), (15, None), (5, 25), (0, 10)]


def oracle(stage, t0, t1):
    rows = {}
    for prim in stage.Traverse():
        path = str(prim.GetPath())
        rows[f"{path} tax"] = sorted(UsdSemantics.LabelsAPI.ComputeInheritedTaxonomies(prim))
        for tax in TAXONOMIES:
            at = UsdSemantics.LabelsQuery(tax, Usd.TimeCode(t0))
            span = UsdSemantics.LabelsQuery(tax, Gf.Interval(t0, t1 if t1 is not None else t0))
            rows[f"{path} {tax} direct"] = sorted(at.ComputeUniqueDirectLabels(prim))
            rows[f"{path} {tax} inherited"] = sorted(at.ComputeUniqueInheritedLabels(prim))
            rows[f"{path} {tax} interval"] = sorted(span.ComputeUniqueInheritedLabels(prim))
    return rows


def native(tool, path, t0, t1):
    rng = f"{t0}:{t1}" if t1 is not None else f"{t0}"
    out = subprocess.run([str(tool), "--dump-semantics", str(path), rng, "-", *TAXONOMIES],
                         check=True, capture_output=True, text=True, timeout=30).stdout
    rows = {}
    for line in out.splitlines():
        parts = line.split()
        if parts[1] == "tax":
            rows[f"{parts[0]} tax"] = parts[2:]
        else:
            rows[" ".join(parts[:3])] = parts[3:]
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lusdcat", type=Path, required=True)
    parser.add_argument("--geom-compare", type=Path, required=True)
    args = parser.parse_args()
    failures, checked = [], 0
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        (folder / "asset.usda").write_text(ASSET)
        scene = folder / "scene.usda"
        scene.write_text(SCENE)
        flat = folder / "scene.usdc"
        subprocess.run([str(args.lusdcat.resolve()), "-f", "--output-format", "usdc",
                        "-o", str(flat), str(scene)], check=True, capture_output=True, timeout=30)
        stage = Usd.Stage.Open(str(scene))
        for t0, t1 in QUERIES:
            expected = oracle(stage, t0, t1)
            for path in (scene, flat):
                got = native(args.geom_compare.resolve(), path, t0, t1)
                for key, want in expected.items():
                    if got.get(key) != want:
                        failures.append(f"{path.suffix} t={t0},{t1} {key}: LightUSD "
                                        f"{got.get(key)} OpenUSD {want}")
                    checked += 1
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"{checked} usdSemantics taxonomy/label queries agree in OpenUSD and LightUSD")


if __name__ == "__main__":
    main()

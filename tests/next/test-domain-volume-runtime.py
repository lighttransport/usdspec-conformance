#!/usr/bin/env python3
"""Compare usdVol field resolution on real OpenVDB files.

OpenUSD resolves each Volume's field relationships and each OpenVDBAsset's
`filePath` (sampled assets are held, not interpolated), `fieldName` and
`fieldIndex` at the probe time. The grid is chosen with the Lean rule
`VolumeValidation.selectFieldGrid` (the `fieldIndex`-th grid named
`fieldName`, or of any name when `fieldName` is empty) over the grid list
that the reference OpenVDB tool `vdb_print -l` reports. The expected grid
facts (name, value type, active voxel count, active index bounds) come from
`vdb_print`, independent of LightUSD's reader. LightUSD's answer is
`geom_compare --dump-volume`, which runs tydra's RenderSceneConverter.

Fixtures are the OpenVDB sample files in --vdb-dir (default
~/work/tinyvdbio/data). The runner exits 77 (skip) when they are missing.
"""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from pxr import Sdf, Usd, UsdVol

FILES = ("smoke.vdb", "fire.vdb", "sphere-div1.vdb", "bunny.vdb")

SCENE = '''#usda 1.0
def Volume "Smoke" {
    rel field:density = </Smoke/D>
    def OpenVDBAsset "D" {
        asset filePath = @./smoke.vdb@
        token fieldName = "density"
    }
}
def Volume "Fire" {
    rel field:density = </Fire/D>
    rel field:temperature = </Fire/T>
    def OpenVDBAsset "D" {
        asset filePath = @./fire.vdb@
        token fieldName = "density"
    }
    def OpenVDBAsset "T" {
        asset filePath = @./fire.vdb@
        token fieldName = "temperature"
    }
}
def Volume "Sampled" {
    rel field:density = </Sampled/D>
    def OpenVDBAsset "D" {
        asset filePath.timeSamples = {0: @./smoke.vdb@, 10: @./fire.vdb@, 20: @./sphere-div1.vdb@}
        token fieldName = "density"
    }
}
def Volume "ByIndex" {
    rel field:second = </ByIndex/S>
    def OpenVDBAsset "S" {
        asset filePath = @./fire.vdb@
        token fieldName = ""
        int fieldIndex = 1
    }
}
def Volume "LevelSet" {
    rel field:surface = </LevelSet/L>
    def OpenVDBAsset "L" {
        asset filePath = @./bunny.vdb@
        token fieldName = "ls_bunny"
        token fieldClass = "levelSet"
    }
}
def Volume "Missing" {
    rel field:density = </Missing/D>
    def OpenVDBAsset "D" {
        asset filePath = @./fire.vdb@
        token fieldName = "nope"
    }
}
'''
TIMES = (0, 5, 10, 25)


def vdb_grids(path):
    """[(name, type, active voxels, (min xyz), (max xyz))] from `vdb_print -l`."""
    text = subprocess.run(["vdb_print", "-l", str(path)], check=True, capture_output=True,
                          text=True).stdout
    grids = []
    for block in text.split("Name: ")[1:]:
        name = block.split("\n", 1)[0].strip()
        vtype = re.search(r"Type: Tree_(\w+?)_\d", block).group(1)
        voxels = int(re.search(r"Number of active voxels:\s+([\d,]+)", block).group(1)
                     .replace(",", ""))
        box = re.search(r"Bounding box of active voxels: \[(-?\d+), (-?\d+), (-?\d+)\] -> "
                        r"\[(-?\d+), (-?\d+), (-?\d+)\]", block)
        grids.append((name, vtype, voxels, tuple(map(int, box.groups()[:3])),
                      tuple(map(int, box.groups()[3:]))))
    return grids


def select_field_grid(grids, name, index):
    """Lean VolumeValidation.selectFieldGrid."""
    if index < 0:
        return None
    matches = [g for g in grids if not name or g[0] == name]
    return matches[index] if index < len(matches) else None


def expected_rows(stage, time, folder):
    rows = {}
    for prim in stage.Traverse():
        if not prim.IsA(UsdVol.Volume):
            continue
        for binding, field_path in UsdVol.Volume(prim).GetFieldPaths().items():
            field = UsdVol.OpenVDBAsset(stage.GetPrimAtPath(field_path))
            asset = field.GetFilePathAttr().Get(time)
            name = field.GetFieldNameAttr().Get(time) or ""
            index = field.GetFieldIndexAttr().Get(time) or 0
            file = Path(asset.resolvedPath or folder / asset.path).name
            grid = select_field_grid(vdb_grids(folder / file), name, index)
            key = f"{prim.GetPath()} {binding}"
            if grid is None:
                rows[key] = "ERROR"
            else:
                gname, vtype, voxels, lo, hi = grid
                occurrence = [g for g in vdb_grids(folder / file) if g[0] == gname].index(grid)
                rows[key] = " ".join(map(str, (file, gname, occurrence, vtype, voxels, *lo, *hi)))
    return rows


def native_rows(tool, scene, time):
    run = subprocess.run([str(tool), "--dump-volume", str(scene), repr(float(time))],
                         check=True, capture_output=True, text=True, timeout=120)
    rows = {}
    for line in run.stdout.splitlines():
        parts = line.split()
        key = f"{parts[0]} {parts[1]}"
        if parts[2] == "ERROR":
            rows[key] = "ERROR"
        else:
            # Drop the class column; compare file, grid, occurrence, type, voxels, bounds.
            rows[key] = " ".join(parts[2:6] + parts[7:])
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lusdcat", type=Path, required=True)
    parser.add_argument("--geom-compare", type=Path, required=True)
    parser.add_argument("--vdb-dir", type=Path, default=Path.home() / "work/tinyvdbio/data")
    args = parser.parse_args()
    if not shutil.which("vdb_print") or not all((args.vdb_dir / f).is_file() for f in FILES):
        print("SKIP: vdb_print or OpenVDB sample files unavailable")
        sys.exit(77)
    failures, checked = [], 0
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        for f in FILES:
            (folder / f).symlink_to(args.vdb_dir / f)
        scene = folder / "volumes.usda"
        scene.write_text(SCENE)
        crate = folder / "volumes.usdc"
        subprocess.run([str(args.lusdcat.resolve()), "--rewrite-layer", "--output-format", "usdc",
                        "-o", str(crate), str(scene)], check=True, capture_output=True, timeout=60)
        stage = Usd.Stage.Open(str(scene))
        for time in TIMES:
            expected = expected_rows(stage, time, folder)
            for path in (scene, crate):
                got = native_rows(args.geom_compare.resolve(), path, time)
                for key, want in expected.items():
                    # A volume none of whose fields resolve is dropped by the
                    # converter: an absent row is an unresolved field.
                    if got.get(key, "ERROR") != want:
                        failures.append(f"{path.suffix}@{time} {key}: LightUSD {got.get(key)!r} "
                                        f"expected {want!r}")
                    checked += 1
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"{checked} volume field resolutions agree: OpenUSD field/asset resolution, Lean "
          f"selectFieldGrid and vdb_print grid facts vs LightUSD (USDA and USDC)")


if __name__ == "__main__":
    main()

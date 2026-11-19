#!/usr/bin/env python3
"""Compare native USDA- and USDC-rooted USDZ packages with Lean scene vectors."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile

from pxr import Sdf, Usd


def authored_fields(layer):
    fields = {}

    def collect(path):
        spec = layer.GetObjectAtPath(path)
        if spec is None:
            return
        values = {key: str(spec.GetInfo(key)) for key in spec.ListInfoKeys()
                  if key != "subLayerOffsets"}
        if path == Sdf.Path.absoluteRootPath and "subLayerOffsets" in spec.ListInfoKeys():
            values["subLayerOffsets"] = [(offset.offset, offset.scale)
                                         for offset in layer.subLayerOffsets]
        fields[str(path)] = values

    # Match specs by path rather than their physical order in the package.
    # Explicit root, prim, and property ordering metadata are still compared.
    layer.Traverse(Sdf.Path.absoluteRootPath, collect)
    return fields


def require_same(actual, expected, context):
    if actual == expected:
        return
    for path in sorted(actual.keys() | expected.keys()):
        if actual.get(path) != expected.get(path):
            raise AssertionError(f"{context}: {path}: expected {expected.get(path)}, "
                                 f"got {actual.get(path)}")
    raise AssertionError(f"{context}: layer specifications differ")


def run(tool, args):
    result = subprocess.run([str(tool), *args], capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise AssertionError(result.stdout + result.stderr)


def replay(case, folder, converter, lusdcat):
    folder.mkdir()
    for name in ("weak", "root", "composed"):
        (folder / f"{name}.usda").write_text(case[name])
    expected_layer = Sdf.Layer.FindOrOpen(str(folder / "composed.usda"))
    assert expected_layer, f"{case['id']}: invalid expected layer"
    expected = authored_fields(expected_layer)

    for encoding in ("usda", "usdc"):
        package = folder / f"scene-{encoding}.usdz"
        run(converter, [str(folder / "root.usda"), str(package),
                        "--rootLayerFormat", encoding, "-noReencode"])
        with zipfile.ZipFile(package) as archive:
            root = archive.infolist()[0]
            if Path(root.filename).suffix != f".{encoding}":
                raise AssertionError(f"{package}: wrong root encoding in {root.filename}")
        stock = Usd.Stage.Open(str(package))
        if not stock:
            raise AssertionError(f"{package}: stock OpenUSD could not open package")
        require_same(authored_fields(stock.GetRootLayer()), expected, str(package))

        output = folder / f"reopened-{encoding}.usda"
        run(lusdcat, ["--rewrite-layer", "--output-format", "usda", "-o",
                      str(output), str(package)])
        native = Sdf.Layer.FindOrOpen(str(output))
        if not native:
            raise AssertionError(f"{package}: native replay did not produce a readable layer")
        require_same(authored_fields(native), expected, str(output))


    retained = folder / "retained.usdz"
    run(converter, [str(folder / "root.usda"), str(retained), "-noFlatten",
                    "--rootLayerFormat", "usda", "-noReencode"])
    with zipfile.ZipFile(retained) as archive:
        if "weak.usda" not in archive.namelist():
            raise AssertionError(f"{retained}: missing packaged layer dependency")
    stock = Usd.Stage.Open(str(retained))
    if not stock:
        raise AssertionError(f"{retained}: stock OpenUSD could not open package")
    root = Sdf.Layer.FindOrOpen(str(folder / "root.usda"))
    require_same(authored_fields(stock.GetRootLayer()), authored_fields(root), str(retained))
    require_same(authored_fields(stock.Flatten(addSourceFileComment=False)), expected, str(retained))

    output = folder / "retained-flattened.usda"
    run(lusdcat, ["--flatten", "--output-format", "usda", "-o", str(output), str(retained)])
    flattened = Sdf.Layer.FindOrOpen(str(output))
    flattened.pseudoRoot.ClearInfo("documentation")
    require_same(authored_fields(flattened), expected, str(output))


def replay_stock_package(case, folder, lusdcat):
    expected = authored_fields(Sdf.Layer.FindOrOpen(str(folder / "composed.usda")))
    for encoding in ("usda", "usdc"):
        stock_dir = folder / f"stock-{encoding}"
        stock_dir.mkdir()
        sources = []
        for name in ("root", "weak"):
            layer = Sdf.Layer.CreateAnonymous(".usda")
            content = case[name].replace("@weak.usda@", f"@weak.{encoding}@")
            if not layer.ImportFromString(content):
                raise AssertionError(f"{case['id']}: invalid stock {name} layer")
            path = stock_dir / f"{name}.{encoding}"
            if not layer.Export(str(path)):
                raise AssertionError(f"{case['id']}: failed to write stock layer {path}")
            sources.append(path)
        package = stock_dir / "stock.usdz"
        # Keep the authored arc and asset paths. The fixture supplies the USD
        # layer dependency and leaves volume data external.
        with Sdf.ZipFileWriter.CreateNew(str(package)) as writer:
            for source in sources:
                if writer.AddFile(str(source), source.name) != source.name:
                    raise AssertionError(f"{package}: failed to add {source.name}")
        stock = Usd.Stage.Open(str(package))
        if not stock:
            raise AssertionError(f"{package}: stock OpenUSD could not open package")
        require_same(authored_fields(stock.Flatten(addSourceFileComment=False)),
                     expected, str(package))
        output = stock_dir / "native.usdc"
        run(lusdcat, ["--flatten", "--output-format", "usdc", "-o",
                      str(output), str(package)])
        native = Sdf.Layer.FindOrOpen(str(output))
        if not native:
            raise AssertionError(f"{package}: LightUSD did not produce a readable layer")
        native.pseudoRoot.ClearInfo("documentation")
        require_same(authored_fields(native), expected, str(output))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lusdzconvert", type=Path, required=True)
    parser.add_argument("--lusdcat", type=Path, required=True)
    parser.add_argument("--vectors", type=Path, default=Path(__file__).resolve().parent
                        / "generated/lean/domain-roundtrip-vectors.json")
    args = parser.parse_args()
    if Usd.GetVersion() != (0, 26, 11):
        raise AssertionError(f"expected stock OpenUSD 26.11, got {Usd.GetVersion()}")
    vectors = json.loads(args.vectors.read_text())
    if not vectors:
        raise AssertionError("empty package replay")
    with tempfile.TemporaryDirectory(prefix="lightusd-domain-package-") as tmp:
        for case in vectors:
            folder = Path(tmp) / case["id"]
            replay(case, folder, args.lusdzconvert.resolve(), args.lusdcat.resolve())
            replay_stock_package(case, folder, args.lusdcat.resolve())
    print(f"{len(vectors) * 3} LightUSD and {len(vectors) * 2} OpenUSD packages matched Lean")


if __name__ == "__main__":
    main()

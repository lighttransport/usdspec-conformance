#!/usr/bin/env python3
"""Compare UsdMediaAssetPreviewsAPI.GetDefaultThumbnails in OpenUSD and LightUSD.

Cases: API applied with a default image, API missing, a non-asset value, a
missing key, and a referenced asset whose assetInfo is overridden. Replayed
from USDA and a flattened USDC written by LightUSD.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

from pxr import Usd, UsdMedia

ASSET = '''#usda 1.0
def Xform "Asset" (
    prepend apiSchemas = ["AssetPreviewsAPI"]
    assetInfo = {
        dictionary previews = {
            dictionary thumbnails = {
                dictionary default = {
                    asset defaultImage = @./thumb.png@
                }
            }
        }
    }
) {
}
'''
SCENE = '''#usda 1.0
def Xform "Applied" (
    prepend apiSchemas = ["AssetPreviewsAPI"]
    assetInfo = {
        dictionary previews = {
            dictionary thumbnails = {
                dictionary default = {
                    asset defaultImage = @images/a.png@
                }
            }
        }
    }
) {
}
def Xform "NoAPI" (
    assetInfo = {
        dictionary previews = {
            dictionary thumbnails = {
                dictionary default = {
                    asset defaultImage = @images/b.png@
                }
            }
        }
    }
) {
}
def Xform "WrongType" (
    prepend apiSchemas = ["AssetPreviewsAPI"]
    assetInfo = {
        dictionary previews = {
            dictionary thumbnails = {
                dictionary default = {
                    string defaultImage = "images/c.png"
                }
            }
        }
    }
) {
}
def Xform "Missing" (
    prepend apiSchemas = ["AssetPreviewsAPI"]
) {
}
def Xform "Referenced" (
    references = @./asset.usda@</Asset>
    assetInfo = {
        dictionary previews = {
            dictionary thumbnails = {
                dictionary default = {
                    asset defaultImage = @./override.png@
                }
            }
        }
    }
) {
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lusdcat", type=Path, required=True)
    parser.add_argument("--geom-compare", type=Path, required=True)
    args = parser.parse_args()
    failures, checked = [], 0
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        (folder / "asset.usda").write_text(ASSET)
        scene = folder / "media.usda"
        scene.write_text(SCENE)
        flat = folder / "media.usdc"
        subprocess.run([str(args.lusdcat.resolve()), "-f", "--output-format", "usdc",
                        "-o", str(flat), str(scene)], check=True, capture_output=True, timeout=30)
        stage = Usd.Stage.Open(str(scene))
        expected = {}
        for prim in stage.Traverse():
            thumbs = UsdMedia.AssetPreviewsAPI(prim).GetDefaultThumbnails()
            expected[str(prim.GetPath())] = thumbs.defaultImage.path if thumbs else "-"
        for path in (scene, flat):
            out = subprocess.run([str(args.geom_compare.resolve()), "--dump-thumbnails", str(path)],
                                 check=True, capture_output=True, text=True, timeout=30).stdout
            got = dict(line.split(" ", 1) for line in out.splitlines())
            for prim, want in expected.items():
                if got.get(prim) != want:
                    failures.append(f"{path.suffix} {prim}: LightUSD {got.get(prim)} OpenUSD {want}")
                checked += 1
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"{checked} usdMedia default-thumbnail results agree in OpenUSD and LightUSD")


if __name__ == "__main__":
    main()

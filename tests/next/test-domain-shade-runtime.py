#!/usr/bin/env python3
"""Compare usdShade binding resolution and UsdCollectionAPI membership.

* Material binding: UsdShade.MaterialBindingAPI.ComputeBoundMaterial for the
  allPurpose, preview and full purposes against `geom_compare --dump-binding`
  (direct and collection bindings, bindMaterialAs strength, dangling targets,
  inheritance).
* Collections: Usd.CollectionAPI.ComputeMembershipQuery().IsPathIncluded
  against `geom_compare --dump-collection` (includes, excludes, includeRoot,
  explicitOnly, nested collections). Light linking (usdLux) uses the same
  query.

Both the authored USDA and a LightUSD-written USDC are replayed.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

from pxr import Usd, UsdShade

HEAD = "#usda 1.0\n"

BINDING_SCENES = {
    "direct-and-strength": '''
def Scope "Looks" {
    def Material "Red" {}
    def Material "Blue" {}
    def Material "Green" {}
    def Material "Preview" {}
    def Scope "NotAMaterial" {}
}
def Xform "World" (prepend apiSchemas = ["MaterialBindingAPI"]) {
    rel material:binding = </Looks/Red>
    def Xform "Weak" {
        def Mesh "Leaf" (prepend apiSchemas = ["MaterialBindingAPI"]) {
            rel material:binding = </Looks/Blue>
        }
        def Mesh "Inherits" {}
    }
    def Xform "Strong" (prepend apiSchemas = ["MaterialBindingAPI"]) {
        rel material:binding = </Looks/Green> (bindMaterialAs = "strongerThanDescendants")
        def Mesh "Leaf" (prepend apiSchemas = ["MaterialBindingAPI"]) {
            rel material:binding = </Looks/Blue>
        }
    }
    def Mesh "Purposes" (prepend apiSchemas = ["MaterialBindingAPI"]) {
        rel material:binding = </Looks/Red>
        rel material:binding:preview = </Looks/Preview>
    }
    def Mesh "FullOnly" (prepend apiSchemas = ["MaterialBindingAPI"]) {
        rel material:binding:full = </Looks/Blue>
    }
    def Mesh "Dangling" (prepend apiSchemas = ["MaterialBindingAPI"]) {
        rel material:binding = </Looks/NotAMaterial>
    }
    def Mesh "Missing" (prepend apiSchemas = ["MaterialBindingAPI"]) {
        rel material:binding = </Looks/Nope>
    }
}
''',
    "collection-bindings": '''
def Scope "Looks" {
    def Material "Red" {}
    def Material "Blue" {}
    def Material "Gold" {}
}
def Xform "World" (
    prepend apiSchemas = ["MaterialBindingAPI", "CollectionAPI:shiny"]
) {
    rel collection:shiny:includes = [</World/A>, </World/B/Deep>]
    rel collection:shiny:excludes = [</World/A/Skip>]
    rel material:binding:collection:shiny = [</World.collection:shiny>, </Looks/Gold>]
    rel material:binding = </Looks/Red>
    rel material:binding:collection:preview:shiny = [</World.collection:shiny>, </Looks/Blue>] (
        bindMaterialAs = "strongerThanDescendants"
    )
    def Mesh "A" {
        def Mesh "Skip" {}
        def Mesh "Kept" {}
    }
    def Xform "B" {
        def Mesh "Deep" (prepend apiSchemas = ["MaterialBindingAPI"]) {
            rel material:binding = </Looks/Blue>
        }
        def Mesh "Other" {}
    }
}
''',
}

SURFACE_SCENE = '''
def Scope "Looks" {
    def Material "Both" {
        token outputs:surface.connect = </Looks/Both/Preview.outputs:surface>
        token outputs:mtlx:surface.connect = </Looks/Both/Graph.outputs:out>
        def Shader "Preview" {
            uniform token info:id = "UsdPreviewSurface"
            token outputs:surface
        }
        def NodeGraph "Graph" {
            token outputs:out.connect = </Looks/Both/Graph/Inner.outputs:mid>
            def NodeGraph "Inner" {
                token outputs:mid.connect = </Looks/Both/Mtlx.outputs:out>
            }
        }
        def Shader "Mtlx" {
            uniform token info:id = "ND_standard_surface_surfaceshader"
            token outputs:out
        }
    }
    def Material "UniversalOnly" {
        token outputs:surface.connect = </Looks/UniversalOnly/S.outputs:surface>
        def Shader "S" {
            token outputs:surface
        }
    }
    def Material "DeadContext" {
        token outputs:mtlx:surface.connect = </Looks/DeadContext/Missing.outputs:out>
        token outputs:surface.connect = </Looks/DeadContext/S.outputs:surface>
        def Shader "S" {
            token outputs:surface
        }
    }
    def Material "RiOnly" {
        token outputs:ri:surface.connect = </Looks/RiOnly/S.outputs:out>
        def Shader "S" {
            token outputs:out
        }
    }
}
'''
CONTEXTS = ["", "mtlx", "ri", "glslfx"]

COLLECTION_SCENE = '''
def Xform "World" (
    prepend apiSchemas = ["CollectionAPI:nearest", "CollectionAPI:root",
                          "CollectionAPI:explicit", "CollectionAPI:outer",
                          "CollectionAPI:inner"]
) {
    rel collection:nearest:includes = [</World/A>, </World/A/B/C>]
    rel collection:nearest:excludes = [</World/A/B>]
    bool collection:root:includeRoot = 1
    rel collection:root:excludes = [</World/A>]
    uniform token collection:explicit:expansionRule = "explicitOnly"
    rel collection:explicit:includes = [</World/A>, </World/A/B/C>]
    rel collection:outer:includes = [</World.collection:inner>, </World/D>]
    rel collection:outer:excludes = [</World/A/B/C>]
    rel collection:inner:includes = [</World/A>]
    def Xform "A" {
        def Xform "B" {
            def Xform "C" {
                def Xform "E" {}
            }
            def Xform "F" {}
        }
    }
    def Xform "D" {}
}
'''
COLLECTIONS = ["nearest", "root", "explicit", "outer", "inner"]


def write_pair(folder, name, text, lusdcat):
    source = folder / f"{name}.usda"
    source.write_text(HEAD + text)
    crate = source.with_suffix(".usdc")
    subprocess.run([str(lusdcat), "--rewrite-layer", "--output-format", "usdc",
                    "-o", str(crate), str(source)], check=True, capture_output=True, timeout=30)
    return source, crate


def dump(tool, *args):
    run = subprocess.run([str(tool), *map(str, args)], check=True, capture_output=True,
                         text=True, timeout=30)
    return dict(line.split(" ", 1) for line in run.stdout.splitlines())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lusdcat", type=Path, required=True)
    parser.add_argument("--geom-compare", type=Path, required=True)
    args = parser.parse_args()
    tool = args.geom_compare.resolve()
    failures, bindings, members, surfaces = [], 0, 0, 0
    purposes = {"all": UsdShade.Tokens.allPurpose, "preview": UsdShade.Tokens.preview,
                "full": UsdShade.Tokens.full}
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        for case, text in BINDING_SCENES.items():
            paths = write_pair(folder, case, text, args.lusdcat.resolve())
            stage = Usd.Stage.Open(str(paths[0]))
            for label, purpose in purposes.items():
                expected = {}
                for prim in stage.Traverse():
                    material, _ = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial(purpose)
                    expected[str(prim.GetPath())] = str(material.GetPath()) if material else "-"
                for path in paths:
                    got = dump(tool, "--dump-binding", path, label)
                    for prim, want in expected.items():
                        if got.get(prim) != want:
                            failures.append(f"{case}{path.suffix} {label} {prim}: "
                                            f"LightUSD {got.get(prim)} OpenUSD {want}")
                        bindings += 1
        paths = write_pair(folder, "surfaces", SURFACE_SCENE, args.lusdcat.resolve())
        stage = Usd.Stage.Open(str(paths[0]))
        for contexts in CONTEXTS:
            expected = {}
            for prim in stage.Traverse():
                if not prim.IsA(UsdShade.Material):
                    continue
                source, name, _ = UsdShade.Material(prim).ComputeSurfaceSource(contexts)
                expected[str(prim.GetPath())] = (
                    f"{source.GetPath()}.outputs:{name}" if source else "-")
            for path in paths:
                got = dump(tool, "--dump-surface", path, contexts or "-")
                for prim, want in expected.items():
                    if got.get(prim) != want:
                        failures.append(f"surface {contexts}{path.suffix} {prim}: "
                                        f"LightUSD {got.get(prim)} OpenUSD {want}")
                    surfaces += 1
        paths = write_pair(folder, "collections", COLLECTION_SCENE, args.lusdcat.resolve())
        stage = Usd.Stage.Open(str(paths[0]))
        world = stage.GetPrimAtPath("/World")
        for name in COLLECTIONS:
            query = Usd.CollectionAPI(world, name).ComputeMembershipQuery()
            expected = {str(p.GetPath()): "1" if query.IsPathIncluded(p.GetPath()) else "0"
                        for p in stage.Traverse()}
            for path in paths:
                got = dump(tool, "--dump-collection", path, "/World", name)
                for prim, want in expected.items():
                    if got.get(prim) != want:
                        failures.append(f"collection {name}{path.suffix} {prim}: "
                                        f"LightUSD {got.get(prim)} OpenUSD {want}")
                    members += 1
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"{bindings} material bindings, {surfaces} render-context surface terminals and "
          f"{members} collection memberships agree in OpenUSD and LightUSD")


if __name__ == "__main__":
    main()

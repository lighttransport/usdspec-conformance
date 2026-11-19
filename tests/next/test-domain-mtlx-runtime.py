#!/usr/bin/env python3
"""Compare MaterialX document translation semantics in OpenUSD and LightUSD.

Each .mtlx in mtlx-runtime/ is referenced into a USD stage
(`@doc.mtlx@</MaterialX>`). OpenUSD translates it with its usdMtlx file-format
plugin (MaterialX-enabled 26.11 build required). LightUSD translates it with
its own `.mtlx` layer loader, and `lusdcat -f` flattens the result. Both stages
are then read with the same UsdShade code:

* the material's `mtlx` surface terminal (ComputeSurfaceSource) and its node
  category;
* for every authored input reachable from the terminal (through NodeGraph
  outputs, nested graphs and NodeGraph interface inputs): the port type and
  either the producing node and output, or the literal value.

OpenUSD lifts every nodedef input to the Material interface without a value.
Inputs that resolve to no value and no producer are ignored on both sides.
"""
import argparse
from pathlib import Path
import subprocess
import sys
import tempfile

from pxr import Sdf, Sdr, Usd, UsdShade

DOCS = Path(__file__).resolve().parent / "mtlx-runtime"
LIGHTUSD_IDS = {"MtlxAutodeskStandardSurface": "standard_surface",
                "MtlxOpenPBRSurface": "open_pbr_surface"}


def category(shader):
    node_id = shader.GetIdAttr().Get() or ""
    if node_id in LIGHTUSD_IDS:
        return LIGHTUSD_IDS[node_id]
    return node_id


def same_category(a, b):
    """OpenUSD ids are nodedef names ND_<category>_<signature>."""
    if a == b:
        return True
    for nd, cat in ((a, b), (b, a)):
        if nd.startswith("ND_") and nd[3:].startswith(cat + "_"):
            return True
    return False


def norm(value):
    if isinstance(value, Sdf.AssetPath):
        return ("asset", value.path)
    if hasattr(value, "__len__") and not isinstance(value, str):
        return tuple(round(float(v), 6) for v in value)
    if isinstance(value, float):
        return round(value, 6)
    return value


def nodedef_default(stage, shader_name, input_name):
    """Sdr default of an input, from the OpenUSD-translated shader's nodedef."""
    for prim in stage.Traverse():
        if prim.GetName() == shader_name and prim.IsA(UsdShade.Shader):
            node = Sdr.Registry().GetShaderNodeByIdentifier(
                UsdShade.Shader(prim).GetIdAttr().Get() or "")
            port = node.GetShaderInput(input_name) if node else None
            if port is not None:
                return norm(port.GetDefaultValue())
    return None


def network(stage):
    """{material: (terminal category, {(node, input): (type, resolved)})}."""
    out = {}
    for prim in stage.Traverse():
        if not prim.IsA(UsdShade.Material):
            continue
        source, _, _ = UsdShade.Material(prim).ComputeSurfaceSource("mtlx")
        if not source:
            out[prim.GetName()] = ("-", {})
            continue
        edges, seen, work = {}, set(), [source]
        while work:
            shader = work.pop()
            if shader.GetPath() in seen:
                continue
            seen.add(shader.GetPath())
            for inp in shader.GetInputs():
                producers = UsdShade.Utils.GetValueProducingAttributes(inp)
                resolved = None
                for attr in producers:
                    owner = attr.GetPrim()
                    if UsdShade.Shader(owner) and owner.IsA(UsdShade.Shader) and \
                            UsdShade.Utils.GetType(attr.GetName()) == UsdShade.AttributeType.Output:
                        resolved = ("node", owner.GetName(),
                                    UsdShade.Utils.GetBaseNameAndType(attr.GetName())[0])
                        work.append(UsdShade.Shader(owner))
                    elif attr.HasAuthoredValue():
                        resolved = ("value", norm(attr.Get()))
                if resolved is None and inp.GetAttr().HasAuthoredValue():
                    resolved = ("value", norm(inp.Get()))
                if resolved is not None:
                    edges[(shader.GetPrim().GetName(), inp.GetBaseName())] = (
                        str(inp.GetTypeName()), resolved)
        out[prim.GetName()] = (category(source), edges)
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lusdcat", type=Path, required=True)
    args = parser.parse_args()
    if Usd.SchemaRegistry().GetSchemaKind("MaterialXConfigAPI") == Usd.SchemaKind.Invalid:
        print("SKIP: OpenUSD build without usdMtlx")
        sys.exit(77)
    failures, checked, defaults = [], 0, 0
    docs = sorted(p for p in DOCS.glob("*.mtlx") if p.name != "lib.mtlx")
    with tempfile.TemporaryDirectory() as tmp:
        for doc in docs:
            scene = Path(tmp) / f"{doc.stem}.usda"
            scene.write_text(f'#usda 1.0\ndef Scope "Looks" (\n    references = @{doc}@</MaterialX>\n)\n{{\n}}\n')
            flat = Path(tmp) / f"{doc.stem}.lightusd.usda"
            subprocess.run([str(args.lusdcat.resolve()), "-f", "-o", str(flat), str(scene)],
                           check=True, capture_output=True, timeout=60)
            pxr_stage = Usd.Stage.Open(str(scene))
            pxr = network(pxr_stage)
            mine = network(Usd.Stage.Open(str(flat)))
            if set(pxr) != set(mine):
                failures.append(f"{doc.name}: materials {sorted(pxr)} vs LightUSD {sorted(mine)}")
            for material, (terminal, edges) in pxr.items():
                lterm, ledges = mine.get(material, ("-", {}))
                if not same_category(terminal, lterm):
                    failures.append(f"{doc.name} {material}: terminal {lterm} vs OpenUSD {terminal}")
                for key, want in sorted(edges.items()):
                    got = ledges.get(key)
                    if got != want:
                        failures.append(f"{doc.name} {material} {key[0]}.{key[1]}: "
                                        f"LightUSD {got} OpenUSD {want}")
                    checked += 1
                for key in sorted(set(ledges) - set(edges)):
                    # LightUSD materializes nodedef defaults as authored values;
                    # accept them only when equal to the Sdr nodedef default.
                    kind, value = ledges[key][1]
                    if kind == "value" and value == nodedef_default(pxr_stage, *key):
                        defaults += 1
                        continue
                    failures.append(f"{doc.name} {material} {key[0]}.{key[1]}: "
                                    f"LightUSD-only {ledges[key]}")
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"{checked} MaterialX ports (types, values, producers through nested graphs and "
          f"interfaces) agree in OpenUSD usdMtlx and LightUSD over {len(docs)} documents "
          f"({defaults} LightUSD-materialized inputs equal their nodedef defaults)")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Replay schema-authored LightUSD layer and stage round trips against Lean and OpenUSD."""
import argparse
import difflib
import json
from pathlib import Path
import subprocess
import tempfile

from pxr import Sdf, Usd, UsdSkel, Vt


def load(path):
    layer = Sdf.Layer.OpenAsAnonymous(str(path))
    if not layer:
        raise AssertionError(f"cannot read layer {path}")
    return layer


def canonical(layer, *, composed=False):
    result = Sdf.Layer.CreateAnonymous(".usda")
    result.TransferContent(layer)
    if composed:
        result.pseudoRoot.ClearInfo("documentation")
    return result.ExportToString()


def compare(label, expected, actual, *, composed=False):
    want = canonical(expected, composed=composed)
    got = canonical(actual, composed=composed)
    if want != got:
        diff = "".join(difflib.unified_diff(
            want.splitlines(keepends=True), got.splitlines(keepends=True),
            fromfile="expected", tofile="actual"))
        raise AssertionError(f"{label}\n{diff}")


def native(tool, source, out, mode, *options):
    output_format = out.suffix.lstrip(".")
    run = subprocess.run(
        [str(tool), mode, *options, "--output-format", output_format, "-o", str(out), str(source)],
        capture_output=True, text=True, timeout=30)
    if run.returncode or not out.is_file():
        raise AssertionError(f"{source.name} -> {out.name}\n{run.stdout}{run.stderr}")
    return load(out)


def replay_case(tool, folder, case):
    folder.mkdir()
    for key in ("weak", "root", "composed"):
        (folder / f"{key}.usda").write_text(case[key])

    root = folder / "root.usda"
    composed = load(folder / "composed.usda")
    stage = Usd.Stage.Open(str(root))
    if not stage:
        raise AssertionError(f"{case['id']}: stock OpenUSD failed to compose")
    compare(f"{case['id']}: OpenUSD composition", composed,
            stage.Flatten(addSourceFileComment=False), composed=True)

    for encoding in ("usda", "usdc"):
        for layer_name in ("weak", "root"):
            source = folder / f"{layer_name}.usda"
            rewritten = folder / f"{layer_name}-rewrite.{encoding}"
            compare(f"{case['id']}: {layer_name} -> {encoding}",
                    load(source), native(tool, source, rewritten, "--rewrite-layer"))
            compare(f"{case['id']}: {layer_name} -> {encoding} -> USDA",
                    load(source), native(tool, rewritten,
                                         folder / f"{layer_name}-{encoding}-reparse.usda",
                                         "--rewrite-layer"))

        flattened = folder / f"composed-native.{encoding}"
        compare(f"{case['id']}: flatten -> {encoding}", composed,
                native(tool, root, flattened, "--flatten"), composed=True)
        compare(f"{case['id']}: flatten -> {encoding} -> USDA", composed,
                native(tool, flattened, folder / f"composed-{encoding}-reparse.usda",
                       "--rewrite-layer"), composed=True)

        # Give the sublayer the extension of its rewritten encoding and
        # re-encode the authored root with the corresponding relative path.
        stack = folder / f"stack-{encoding}"
        stack.mkdir()
        (stack / f"weak.{encoding}").write_bytes(
            (folder / f"weak-rewrite.{encoding}").read_bytes())
        stack_source = stack / "source.usda"
        stack_source.write_text(case["root"].replace("@weak.usda@", f"@weak.{encoding}@"))
        written_root = stack / f"root.{encoding}"
        native(tool, stack_source, written_root, "--rewrite-layer")
        compare(f"{case['id']}: compose rewritten {encoding} input", composed,
                native(tool, written_root, stack / "result.usda", "--flatten"),
                composed=True)


    stock_stack = folder / "stock-usdc"
    stock_stack.mkdir()
    for layer_name in ("weak", "root"):
        source = load(folder / f"{layer_name}.usda")
        if layer_name == "root":
            if not source.ImportFromString(case["root"].replace("@weak.usda@", "@weak.usdc@")):
                raise AssertionError(f"{case['id']}: invalid stock crate root")
        crate = stock_stack / f"{layer_name}.usdc"
        if not source.Export(str(crate)):
            raise AssertionError(f"{case['id']}: OpenUSD could not write {crate}")
        compare(f"{case['id']}: read stock {layer_name} USDC", source,
                native(tool, crate, stock_stack / f"{layer_name}.usda", "--rewrite-layer"))
    compare(f"{case['id']}: compose stock USDC inputs", composed,
            native(tool, stock_stack / "root.usdc", stock_stack / "result.usdc",
                   "--flatten"), composed=True)


    compare(f"{case['id']}: batched flatten -> USDC", composed,
            native(tool, root, folder / "composed-batched.usdc",
                   "--flatten", "--memory-profile", "low"), composed=True)


    if "deferred" in case:
        deferred = Sdf.Layer.CreateAnonymous(".usda")
        if not deferred.ImportFromString(case["deferred"]):
            raise AssertionError(f"{case['id']}: invalid deferred layer")
        stock = Usd.Stage.Open(str(root), load=Usd.Stage.LoadNone)
        if not stock:
            raise AssertionError(f"{case['id']}: OpenUSD failed to compose deferred payload")
        compare(f"{case['id']}: OpenUSD deferred payload", deferred,
                stock.Flatten(addSourceFileComment=False), composed=True)
        for encoding in ("usda", "usdc"):
            compare(f"{case['id']}: deferred payload -> {encoding}", deferred,
                    native(tool, root, folder / f"deferred.{encoding}",
                           "--flatten", "--defer-payloads"), composed=True)


def catalog_fixture(catalog, mode, sublayer="@weak.usda@"):
    if not catalog or len({schema["name"] for schema in catalog}) != len(catalog):
        raise AssertionError("schema declarations missing or duplicated")
    authored = []
    overrides = []
    flattened = []
    for index, schema in enumerate(catalog):
        name = schema["name"]
        kind = schema["kind"]
        api = None
        if kind in ("singleApplyAPI", "multipleApplyAPI"):
            api = name
            if schema["instance"]:
                api += ":" + schema["instance"]
            allowed = schema["canOnlyApplyTo"]
            prim_type = allowed[0] if allowed else "Xform"
        elif kind == "nonAppliedAPI":
            # These schemas expose helpers without an applied API opinion.
            prim_type = "Xform"
        else:
            prim_type = name
        specifier = "class" if kind in ("abstractTyped", "abstractBase") else "def"
        prim = f"Catalog_{index}"
        header = f'{specifier} {prim_type} "{prim}"'
        weak_body = []
        strong_body = []
        resolved_body = []
        for prop in schema["properties"]:
            if prop["relationship"]:
                declaration = f'    rel {prop["name"]}'
            else:
                qualifier = "uniform " if prop["uniform"] else ""
                declaration = f'    {qualifier}{prop["type"]} {prop["name"]}'
            samples = prop["samples"] if mode in (
                "samples", "shadowed-samples", "samples-over-defaults") else None
            if samples is not None and mode == "samples-over-defaults":
                default = f'{declaration} = {prop["weakValue"]}'
                timestep = f'{declaration}.timeSamples = {samples["samplesOverDefault"]}'
                weak_body.append(default)
                strong_body.append(timestep)
                resolved_body.extend((default, timestep))
            elif samples is not None:
                weak_body.append(f'{declaration}.timeSamples = {samples["weak"]}')
                if mode == "shadowed-samples":
                    opinion = f'{declaration} = {samples["strongDefault"]}'
                    strong_body.append(opinion)
                    resolved_body.append(opinion)
                else:
                    resolved_body.append(f'{declaration}.timeSamples = {samples["resolved"]}')
                    if samples["strong"] is not None:
                        strong_body.append(f'{declaration}.timeSamples = {samples["strong"]}')
            elif mode == "values":
                if prop["weakValue"] is None or prop["resolvedValue"] is None:
                    raise AssertionError(f'{name}.{prop["name"]} has no typed witness')
                weak_body.append(f'{declaration} = {prop["weakValue"]}')
                resolved_body.append(f'{declaration} = {prop["resolvedValue"]}')
                if prop["strongValue"] is not None:
                    strong_body.append(f'{declaration} = {prop["strongValue"]}')
            elif mode == "fallbacks" and prop["fallback"] is not None:
                weak_body.append(f'{declaration} = {prop["fallback"]}')
                resolved_body.append(f'{declaration} = {prop["fallback"]}')
            else:
                weak_body.append(declaration)
                resolved_body.append(declaration)
        for output, operator, body in (
            (authored, "prepend ", weak_body), (flattened, "", resolved_body)
        ):
            metadata = f' ({operator}apiSchemas = ["{api}"])' if api else ""
            output.append(header + metadata + "\n{\n" + "\n".join(body) + "\n}\n")
        if strong_body:
            overrides.append(f'over "{prim}"\n{{\n' + "\n".join(strong_body) + "\n}\n")
    if mode == "values":
        for output in (authored, flattened):
            output.extend(['def Xform "WeakTarget" {}\n', 'def Xform "StrongTarget" {}\n'])
    return {
        "id": f"all-domain-{mode}",
        "weak": "#usda 1.0\n" + "".join(authored),
        "root": f"#usda 1.0\n(subLayers = [{sublayer}])\n" + "".join(overrides),
        "composed": "#usda 1.0\n" + "".join(flattened),
    }


def check_builtin_apis(catalog):
    registry = Usd.SchemaRegistry()
    for schema in catalog:
        name = schema["name"]
        kind = schema["kind"]
        expected = schema["builtInAPIs"]
        if kind == "concreteTyped":
            definition = registry.FindConcretePrimDefinition(name)
        elif kind == "singleApplyAPI":
            definition = registry.FindAppliedAPIPrimDefinition(name)
            expected = [name, *expected]
        else:
            continue
        if not definition and name == "MaterialXConfigAPI":
            # Stock wheels may omit the MaterialX plugin. Authored opinions
            # still run through the generic parser and composition replay.
            continue
        actual = list(definition.GetAppliedAPISchemas()) if definition else None
        if expected != actual:
            raise AssertionError(f"{name}: expected built-in APIs {expected}, got {actual}")


def check_property_declarations(catalog):
    registry = Usd.SchemaRegistry()
    checked = 0
    fallbacks = 0
    expected_layer = Sdf.Layer.CreateAnonymous(".usda")
    if not expected_layer.ImportFromString(catalog_fixture(catalog, "fallbacks")["weak"]):
        raise AssertionError("invalid generated fallback fixture")
    for index, schema in enumerate(catalog):
        name = schema["name"]
        kind = schema["kind"]
        if kind == "concreteTyped":
            definition = registry.FindConcretePrimDefinition(name)
        elif kind in ("abstractTyped", "abstractBase"):
            definition = registry.FindAbstractPrimDefinition(name)
        elif kind in ("singleApplyAPI", "multipleApplyAPI"):
            definition = registry.FindAppliedAPIPrimDefinition(name)
        else:
            if schema["properties"]:
                raise AssertionError(f"{name}: no stock definition for property declarations")
            continue
        if not definition:
            if name == "MaterialXConfigAPI":
                print(f"{name}: declarations checked through pinned schema source and authored replay")
                continue
            raise AssertionError(f"{name}: stock schema definition missing")
        for prop in schema["properties"]:
            prop_name = prop["name"]
            if schema["instance"]:
                prop_name = prop_name.replace(f':{schema["instance"]}:', ":__INSTANCE_NAME__:")
            spec = definition.GetSchemaPropertySpec(prop_name)
            if prop["relationship"]:
                if not isinstance(spec, Sdf.RelationshipSpec):
                    raise AssertionError(f"{name}.{prop_name}: expected stock relationship, got {spec}")
            else:
                variability = Sdf.VariabilityUniform if prop["uniform"] else Sdf.VariabilityVarying
                expected = prop["type"], variability, prop["fallback"] is not None
                actual = (str(spec.typeName), spec.variability, spec.HasDefaultValue()) if (
                    isinstance(spec, Sdf.AttributeSpec)) else None
                if actual != expected:
                    raise AssertionError(f"{name}.{prop_name}: expected {expected}, got {actual}")
                if prop["fallback"] is not None:
                    authored = expected_layer.GetAttributeAtPath(
                        f'/Catalog_{index}.{prop["name"]}')
                    if not authored or repr(authored.default) != repr(spec.default):
                        raise AssertionError(f"{name}.{prop_name}: stock fallback "
                                             f"{spec.default!r} differs from {prop['fallback']}")
                    fallbacks += 1
            checked += 1
    print(f"{checked} Lean property declarations and {fallbacks} fallbacks "
          "matched the stock schema registry")


def check_materialx_sdr_ports():
    from pxr import Sdr, UsdMtlx  # Import the optional plugin before discovery.

    vectors = Path(__file__).resolve().parent / "generated/lean/domain-composed-validation-vectors.json"
    probes = {(port["node"], port["output"], port["name"], port["type"])
              for case in json.loads(vectors.read_text()) for port in case.get("materialXPorts", [])}
    if not probes:
        raise AssertionError("missing Lean MaterialX shader registry probes")
    registry = Sdr.Registry()
    for node_id, output, name, expected in sorted(probes):
        node = registry.GetShaderNodeByIdentifier(node_id)
        if not node:
            raise AssertionError(f"{node_id}: missing OpenUSD shader definition")
        port = node.GetShaderOutput(name) if output else node.GetShaderInput(name)
        actual = str(port.GetTypeAsSdfType().GetSdfType()) if port else ""
        if actual != expected:
            raise AssertionError(f"{node_id}.{name}: expected Sdr type {expected}, got {actual}")
    print(f"{len(probes)} Lean MaterialX ports matched the OpenUSD shader registry")


def check_skeleton_topology():
    path = Path(__file__).resolve().parent / "generated/lean/domain-skeleton-topology-vectors.json"
    probes = json.loads(path.read_text())
    for probe in probes:
        topology = UsdSkel.Topology(Vt.TokenArray(probe["joints"]))
        parents = list(topology.GetParentIndices())
        expected = probe["parents"]
        ordered = all(parent < child for child, parent in enumerate(expected))
        valid, reason = topology.Validate()
        if parents != expected or valid != ordered:
            raise AssertionError(f"{probe['joints']}: expected parents {expected} and "
                                 f"ordered={ordered}, got {parents}, {valid}: {reason}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lusdcat", required=True, type=Path)
    parser.add_argument("--vectors", type=Path, default=Path(__file__).resolve().parent
                        / "generated/lean/domain-roundtrip-vectors.json")
    parser.add_argument("--declarations", type=Path, default=Path(__file__).resolve().parent
                        / "generated/lean/domain-declaration-vectors.json")
    parser.add_argument("--require-materialx", action="store_true",
                        help="require the OpenUSD MaterialX schema plugin")
    args = parser.parse_args()
    if Usd.GetVersion() != (0, 26, 11):
        raise AssertionError(f"expected stock OpenUSD 26.11, got {Usd.GetVersion()}")
    if args.require_materialx and not Usd.SchemaRegistry().FindAppliedAPIPrimDefinition(
            "MaterialXConfigAPI"):
        raise AssertionError("OpenUSD MaterialXConfigAPI schema plugin is required")
    cases = json.loads(args.vectors.read_text())
    if not cases or len({case["id"] for case in cases}) != len(cases):
        raise AssertionError("empty cases or duplicate case identifiers")
    matrix = json.loads(args.declarations.read_text())
    catalog = matrix["schemas"]
    check_builtin_apis(catalog)
    check_property_declarations(catalog)
    if args.require_materialx:
        check_materialx_sdr_ports()
    check_skeleton_topology()
    focused_count = len(cases)
    cases.extend([
        catalog_fixture(catalog, "declarations"),
        catalog_fixture(catalog, "values"),
        catalog_fixture(catalog, "fallbacks"),
        catalog_fixture(catalog, "samples", matrix["sampleSublayer"]),
        catalog_fixture(catalog, "shadowed-samples", matrix["sampleSublayer"]),
        catalog_fixture(catalog, "samples-over-defaults", matrix["sampleSublayer"]),
    ])
    with tempfile.TemporaryDirectory(prefix="lightusd-domain-roundtrip-") as directory:
        for case in cases:
            replay_case(args.lusdcat.resolve(), Path(directory) / case["id"], case)
    print(f"{focused_count} focused scenes and {len(catalog)} schema declaration, value, fallback, and sample sets pass "
          "native parser, composition, and USDA/USDC writers")


if __name__ == "__main__":
    main()

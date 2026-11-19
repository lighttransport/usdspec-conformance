#!/usr/bin/env python3
"""Compare UsdRenderComputeSpec in OpenUSD and LightUSD.

UsdRenderComputeSpec is C++-only, so the oracle tests/next/oracle/render_spec.cc
is compiled against a local OpenUSD 26.11 prefix (--openusd-prefix, with
headers and libs). It is compared with `geom_compare --dump-render-spec`
(lightusd::ComputeRenderSpec) on render-runtime/*.usda and on
LightUSD-flattened USDC copies. The comparison covers product inheritance of
the settings base (only authored product opinions override), camera
apertures conformed by every aspectRatioConformPolicy, dataWindowNDC, motion
blur and DOF flags, ordered vars (non-RenderVar targets dropped),
includedPurposes, and composition through a reference.

Known OpenUSD gap: issues/OpenUSD/16 (instantaneousShutter is ignored).
LightUSD follows the schema doc, so the runner records this difference
instead of failing. Exits 77 when the oracle cannot be built.
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import sysconfig
import tempfile

HERE = Path(__file__).resolve().parent
SCENES = HERE / "render-runtime"


def build_oracle(prefix, out):
    deps = os.environ.get("OPENUSD_DEPS_INCLUDE", str(Path.home() / "work/tinyusdz/OpenUSD/deps/inst/include"))
    py_lib = sysconfig.get_config_var("LIBDIR")
    cmd = ["g++", "-std=c++17", "-O1", "-w", str(HERE / "oracle/render_spec.cc"),
           f"-I{prefix}/include", f"-I{sysconfig.get_paths()['include']}", f"-I{deps}",
           f"-L{prefix}/lib", f"-L{py_lib}", f"-Wl,-rpath,{prefix}/lib", f"-Wl,-rpath,{py_lib}",
           "-Wl,--allow-shlib-undefined", "-lusd_usdRender", "-lusd_usdGeom", "-lusd_usd",
           "-lusd_sdf", "-lusd_tf", "-lusd_gf", "-lusd_vt", "-lusd_python",
           f"-lpython{sysconfig.get_config_var('LDVERSION')}", "-o", str(out)]
    return subprocess.run(cmd, capture_output=True, text=True).returncode == 0


def run(cmd, env=None):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, timeout=60,
                          env=env).stdout.splitlines()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lusdcat", type=Path, required=True)
    parser.add_argument("--geom-compare", type=Path, required=True)
    parser.add_argument("--openusd-prefix", type=Path,
                        default=HERE.parents[1] / "build/openusd-local")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        oracle = Path(tmp) / "render_spec"
        if not (args.openusd_prefix / "include/pxr/usd/usdRender/spec.h").is_file() or \
                not build_oracle(args.openusd_prefix, oracle):
            print("SKIP: cannot build the UsdRenderComputeSpec oracle")
            sys.exit(77)
        env = dict(os.environ, LD_LIBRARY_PATH=f"{args.openusd_prefix}/lib")
        env.pop("PXR_PLUGINPATH_NAME", None)
        failures, checked, gaps = [], 0, 0
        for scene in sorted(SCENES.glob("*.usda")):
            flat = Path(tmp) / f"{scene.stem}.usdc"
            subprocess.run([str(args.lusdcat.resolve()), "-f", "--output-format", "usdc",
                            "-o", str(flat), str(scene)], check=True, capture_output=True,
                           timeout=60)
            expected = run([str(oracle), str(scene)], env)
            for path in (scene, flat):
                got = run([str(args.geom_compare.resolve()), "--dump-render-spec", str(path)])
                if len(got) != len(expected):
                    failures.append(f"{path.name}: {len(got)} lines vs OpenUSD {len(expected)}")
                for mine, want in zip(got, expected):
                    if mine != want:
                        a, b = mine.split(), want.split()
                        diff = [(a[i - 1], a[i], b[i]) for i in range(1, min(len(a), len(b)))
                                if a[i] != b[i]]
                        if path.stem == "instantaneous" and diff == [("mb", "1", "0")]:
                            gaps += 1  # issues/OpenUSD/16
                        else:
                            failures.append(f"{path.name}:\n  LightUSD {mine}\n  OpenUSD  {want}")
                    checked += 1
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"{checked} UsdRenderComputeSpec lines agree in OpenUSD and LightUSD "
          f"(USDA and flattened USDC; {gaps} known OpenUSD gap, issues/OpenUSD/16)")


if __name__ == "__main__":
    main()

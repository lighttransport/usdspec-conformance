#!/usr/bin/env python3
"""Check Lean-predicted diagnostics before and after LightUSD composition."""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess
import tempfile


def check(tool, path, rule, counts, *, composed=False, error_times=None, diagnostic_prim="/Subject"):
    mode = ["--composed", "--skip-variants"] if composed else []
    if error_times is not None:
        mode.append("--all-time-samples")
    run = subprocess.run(
        [str(tool), "--json", "--groups", "geom,physics,shade",
         "--no-asset-checks", *mode, str(path)],
        text=True, capture_output=True, timeout=30)
    if run.returncode not in (0, 1):
        raise AssertionError(f"{path}: checker failed\n{run.stdout}{run.stderr}")
    report = json.loads(run.stdout)
    if not report["executionSuccessful"] or not report["complete"]:
        raise AssertionError(f"{path}: incomplete validation\n{run.stdout}")
    issues = [issue for issue in report["issues"] if issue["ruleId"] == rule]
    timed = [issue for issue in issues if "time" in issue]
    if any(issue["severity"] != "error" for issue in timed) or (
            Counter(issue["time"] for issue in timed) != Counter(error_times or [])):
        raise AssertionError(f"{path}: expected {rule} errors at {error_times}, got {timed}")
    actual = Counter(issue["severity"] for issue in issues if "time" not in issue)
    if dict(actual) != {key: n for key, n in zip(("error", "warning"), counts) if n}:
        raise AssertionError(f"{path}: expected {rule} counts {counts}, got {issues}")
    if any(issue["location"] != diagnostic_prim
           and not issue["location"].startswith(diagnostic_prim + ".")
           for issue in issues):
        raise AssertionError(f"{path}: diagnostic outside subject prim: {issues}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lusdcat", type=Path, required=True)
    parser.add_argument("--lusdchecker", type=Path, required=True)
    args = parser.parse_args()
    vector_path = Path(__file__).resolve().parent / "generated/lean/domain-composed-validation-vectors.json"
    probes = json.loads(vector_path.read_text())
    if not probes or len({probe["id"] for probe in probes}) != len(probes):
        raise AssertionError("composed probes missing or duplicated")
    checker = args.lusdchecker.resolve()
    with tempfile.TemporaryDirectory(prefix="lightusd-domain-diagnostics-") as directory:
        for probe in probes:
            case = Path(directory) / probe["id"]
            case.mkdir()
            weak, root, out = (case / name for name in ("weak.usda", "root.usda", "stage.usdc"))
            weak.write_text(probe["weak"])
            root.write_text(probe["root"])
            rule = probe["rule"]
            diagnostic_prim = probe.get("diagnosticPrim", "/Subject")
            check(checker, weak, rule, probe["weakCounts"],
                  error_times=probe.get("weakErrorTimes"), diagnostic_prim=diagnostic_prim)
            check(checker, root, rule, probe["composedCounts"], composed=True,
                  error_times=probe.get("composedErrorTimes"), diagnostic_prim=diagnostic_prim)
            subprocess.run(
                [str(args.lusdcat.resolve()), "--flatten", "--output-format", "usdc",
                 "-o", str(out), str(root)], check=True, capture_output=True, timeout=30)
            check(checker, out, rule, probe.get("flattenedCounts", probe["composedCounts"]),
                  composed=probe.get("composedOnly", False),
                  error_times=probe.get("composedErrorTimes"), diagnostic_prim=diagnostic_prim)
    print(f"{len(probes)} native authored, composed, and USDC-reopened diagnostics match Lean")


if __name__ == "__main__":
    main()

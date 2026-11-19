# usdspec-conformance

[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/lighttransport)

LEAN 4 model of the AOUSD USD Core Specification (v1.1), plus differential
conformance tests that replay Lean-generated vectors against stock OpenUSD and
LightUSD. It records where the specification is ambiguous, self-contradictory
or differs from OpenUSD behavior, as a citation-checked findings registry with
issue drafts.

Rendered pages (intro, status, findings registry): for humans as HTML, for AI
agents as markdown at the same path —
<https://usdspec-conformance.lighttransport.workers.dev/>

An independent project led by Light Transport Entertainment Inc.
Not affiliated with or endorsed by the Alliance for OpenUSD (AOUSD).

## Layout

| Path | Contents |
|---|---|
| `verif/lean/` | Lean package `UsdSpec` (proofs), generators (`Gen/`), runtime checks (`Check/`), axiom audit (`Audit/`), findings registry `ISSUES.md`, model classification `data/`, `REFLECTION.md` |
| `tests/next/` | Differential tests (LightUSD `lusdcat` vs stock OpenUSD), AOUSD supplemental runner, allowlists, generated vectors in `generated/lean/` |
| `scripts/` | Registry/citation/model-split gates, Unicode data tooling, oracle setup |
| `aousd/core/1.1.0/` | Vendored spec (byte-identical, own `LICENSE`, `PROVENANCE.md`, `SHA256SUMS`) |
| `issues/` | Issue drafts and reviews (`aousd/`, `OpenUSD/`). **Local drafts and historical filing/review records.** |
| `doc/validation/` | Execution ledger `lean-followup-status.md` and audit notes |

## Quick start

```sh
# 1. Lean proofs and registry gates only (needs elan/lake and python3)
cmake -S . -B build
ctest --test-dir build -L lean         # build, tests, axiom audit, vector drift
ctest --test-dir build -R 'spec_citations|model_split|issue_tags'

# 2. Differential conformance (needs a LightUSD build and the stock oracle)
scripts/setup-oracle.sh                # installs usd-core==26.11 under build/
cmake -S . -B build \
  -DLIGHTUSD_ROOT=/path/to/lightusd \
  -DLIGHTUSD_BUILD_DIR=/path/to/lightusd/build \
  -DORACLE_PYTHON=python3.11 \
  -DORACLE_PYTHONPATH=$PWD/build/stock-openusd-oracle/site-packages \
  -DAOUSD_SUPPLEMENTAL_ROOT=/path/to/core-spec-supplemental/releases/1.0.1
ctest --test-dir build -j4 --output-on-failure
```

Unicode reference data (UCD 15.1.0, hash-pinned) is fetched by
`scripts/fetch-lean-unicode-data.py` into `build/unicode-15.1.0`. The AOUSD
supplemental suite is fetched by `scripts/fetch-aousd-supplemental.sh`.
Tests that need `LIGHTUSD_ROOT` report a skip when it is unset (exit 77), not a pass.

## Status

See [`doc/STATUS.md`](doc/STATUS.md) for the full summary and
`doc/validation/lean-followup-status.md` (the ledger) for exact scope and
open items. Headline numbers at the time of the split:

- Lean: full build, 20 generated artifacts with no drift, axiom audit (standard
  axioms only), no `sorry`.
- Strict lossless PCP comparison against stock OpenUSD 26.11: 120 exact / 15
  differing of 135 composition cases (ratchet `STRICT_PCP_ORACLE_DIFF`, goal 0).
  Do not call this parity.
- General NFC idempotence is **not proved**; the evidence is the official
  normalization corpus, a bounded sweep and table-invariant checks.
- Registry: 73 findings, each citation checked mechanically and re-read by an
  independent reviewer; claims depending on OpenUSD behavior are recorded as
  stock-oracle observations, not proofs.

## Relationship to LightUSD

LightUSD (`src/`) is the implementation under test. The Lean generators here
are the source of truth for `tests/next/generated/lean/*.inc`; LightUSD's own C++
consumers (`test_lean_vectors` etc.) read a copy of those files, which must be
refreshed from this repository whenever the generators change.

## Complete local verification

`scripts/verify-local.sh` builds the required LightUSD consumers and a core-only
OpenUSD from source under `build/`, then runs the complete suite. Defaults are
`LIGHTUSD_ROOT=$HOME/work/tinyusdz/main`,
`OPENUSD_ROOT=$HOME/work/tinyusdz/OpenUSD`, and `JOBS=4`. Override
`LOCAL_ORACLE_PYTHON` if the OpenUSD checkout has no `.venv/bin/python3`.
Lean/Mathlib dependencies remain pinned; an existing shared `.lake` symlink is
copied locally without changing its target. Initial setup needs network access
for missing Lean, Unicode, wheel, or supplemental dependencies.

The script enables `USDSPEC_REQUIRE_FULL_SUITE`: absent native consumers fail
configuration. Stock-wheel tests retain their existing names; `local_*` tests
carry the `oracle-local` label and require an independently installed local
OpenUSD 26.11. Configure those tests manually with `LOCAL_OPENUSD_ROOT`,
`LOCAL_OPENUSD_PREFIX`, and `LOCAL_ORACLE_PYTHON`. Local runtime provenance
records the checkout revision, tracked dirty state, USD version, and Python module.
Local results describe fork compatibility; the pinned stock wheel remains the
conformance baseline. Both tracks retain the 15-case strict PCP ceiling.

The combined execution log is `build/verification.log`; JUnit output is
`build/results.xml`. Checked oracle provenance is saved separately in
`build/stock-provenance.json` and `build/local-provenance.json`. `ctest --test-dir build -L lean` includes Unicode and
negative axiom controls. Native vector replay, both combine-chain consumers,
and the other supplemental categories are also registered when available.

## Licensing

Original project code is Apache-2.0. Third-party material has separate terms:
see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The vendored AOUSD text
remains unmodified under CC BY-ND 4.0; attributed quotations retain that license.
The transformed grammar is generated locally for auditing and excluded from the
distributed source. CTest prepares it automatically. Before running Lake directly,
run `python3 scripts/extract-usda-peg.py --lean` from this repository's root.
Do not publish the local transformed grammar or compiled audit modules containing it.


## USD schema domain catalogs

The Lean catalogs under `UsdSpec/Domains` are generated from the OpenUSD
`v26.11.0` schema layers and plugin registrations. Regenerate or check them
using OpenUSD 26.11 Python bindings and a checkout that contains that tag.

```sh
python3 scripts/generate-domain-catalogs.py /path/to/OpenUSD --check --check-registry
```

The generated layers give inherited property declarations as emitted by
`usdGenSchema`. Catalog fallbacks are serialized as USDA literals with their
declared value types. The round-trip gate replays these literals as authored
values so it checks exact preservation of the source defaults.

The stock registry comparison checks observable schema kinds and property
definitions. Builds without the optional USD MaterialX plugin report
`MaterialXConfigAPI` as source-only coverage.

Native registry replay checks each catalog schema's kind and parent, and
every concrete or applied property declaration through an unauthored prim.
Built-in API lists are checked in expansion order, including nested volume
APIs and the collision group's named collection.
The production registry table is generated from this catalog, with properties
inherited through the schema parents. The diagnostic replay covers these
authored-layer rules.

| Family | Diagnostic coverage |
| --- | --- |
| Geometry | Mesh topology, GeomSubset partitions, Points arrays and widths, PointInstancer arrays and indices, and BasisCurves varying widths |
| Skeleton | Joint topology, animation and blend-shape array sizes, and inbetween weights |
| Physics | Axis, joint limits, gravity, authored scalar ranges, drive values, and center-of-mass sentinels |
| MaterialX | Configuration API placement and the version opinion |
| Volume | Field assets, resolved targets, particle providers, array sizes, and spherical harmonics |

The root-count and MaterialX version recommendations reflect LightUSD policy.
The authored-layer replay checks error and warning counts, including cases
with multiple findings for the same rule. The skeleton array models cover
representable sample maps with finite, ordered time codes.

The `domain_composed_validation` gate checks stronger opinions that introduce
or clear findings across all five families. Each case checks the weak layer,
the composed stage, and the stage reopened from flattened USDC.

The composed cases include sampled extents, mesh normals, and PointInstancer
topology and orientations. They also exercise inherited skinning influences,
joint and collider relationships, MaterialX port and terminal connections,
and forwarded Volume fields. A case can declare distinct expectations when
flattening drops authorship information, as it does for an explicit field
relationship block.

The `domain_roundtrip` conformance test compares field and list-op opinions
in authored layers and flattened stages. Lean supplies the expected strongest
opinions across the layer stack. Stock OpenUSD composes the same inputs and
reads the native USDA and USDC outputs. LightUSD reopens both encodings
and composes stacks of crates written by both implementations. External references and loaded payloads
check namespace remapping of relationship targets and shader connections.
Deferred payload cases check that local opinions survive without payload contents.
The gate also authors every property declaration in the five-family catalog, including
declared-only relationships and concrete instances of multiple-apply APIs.
For each declaration it also replays a typed default or relationship target.
The sample matrix covers varying attributes with rational sublayer offsets
and tests stronger sample maps, stronger defaults and blocks that suppress
weaker samples, and weaker sample maps that survive. Stronger sample maps can
also coexist with weaker defaults, including maps with blocked time samples.

Use the Python interpreter and module path from a MaterialX-enabled OpenUSD
26.11 installation to run the strict registry check. Make the installation's
MaterialX shared libraries available to the dynamic loader if required.
For CTest, configure those Python paths with `ORACLE_PYTHON` and
`ORACLE_PYTHONPATH`, set `ORACLE_REQUIRE_MATERIALX=ON`, and use
`ORACLE_MATERIALX_LIBRARY_PATH` if the shared libraries need a loader path.

```sh
python tests/next/test-domain-roundtrip.py --require-materialx \
  --lusdcat /path/to/LightUSD/build_ninja/lusdcat
```

The `domain_package` gate replays the focused scenes through `lusdzconvert`.
It compares USDA- and USDC-rooted flattened packages and packages that
retain their sublayers, references, or payloads. Both LightUSD and stock OpenUSD
reopen and compose the retained packages, including packages written by
OpenUSD with USDA and USDC roots. The volume scenes test the
layer's asset path opinions without loading volume payloads.


The skeleton deformation gate also checks a dual-quaternion discriminator
against stock OpenUSD. With zero translations and a blend of identity and
a half-turn, it verifies that the two skinning methods produce different
points. LightUSD validates both method tokens in authored USD, while its
deformation evaluator currently supports classic linear skinning.

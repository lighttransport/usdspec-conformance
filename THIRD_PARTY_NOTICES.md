# Licensing and attribution boundaries

The root Apache-2.0 license applies to original project code, proofs, commentary,
and independently authored tests. It does not relicense third-party expression,
quoted specification passages, or Unicode data. No blanket fair-use or clean-room
assertion is made.

An independent project led by Light Transport Entertainment Inc.
Not affiliated with or endorsed by the Alliance for OpenUSD (AOUSD).

## AOUSD Core Specification 1.1.0

Copyright © 2026 Alliance for OpenUSD (AOUSD), Core Spec Working Group Authors.
Source: https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md
License: Creative Commons Attribution-NoDerivatives 4.0 International:
https://creativecommons.org/licenses/by-nd/4.0/
Full license: [aousd/core/1.1.0/LICENSE](aousd/core/1.1.0/LICENSE).
Provenance and byte hashes: [PROVENANCE.md](aousd/core/1.1.0/PROVENANCE.md).

The vendored document is reproduced unchanged. Short attributed passages in
issue reports and Lean documentation are excerpts used to identify and discuss
particular claims; quoted expression retains its source license. Author-written
analysis, proposed corrections, and mathematical models are distinguished from
those excerpts; they are not an authorized revised edition of the specification.
The CC license grants copying of unmodified material in whole or part, subject
to its conditions. We do not rely on the label "fair use" to license a rewritten
specification. Statutory exceptions, where applicable, are jurisdiction-specific.

The full expanded/transformed grammar is **not distributed as project source**.
`Rules.lean` is only an import facade. `scripts/extract-usda-peg.py` reads the
hash-verified licensed original to produce ignored `GeneratedRules.lean` for
local audit, including separately identified repair proposals. Do not publish
that file, JSON/example extraction output, or compiled audit modules containing
it without establishing the necessary redistribution rights. CI caches only
third-party Lake dependencies, not the project's compiled audit grammar.

Every revision intended for publication must exclude the full transformed grammar
and repaired specification-example layers, not merely the current checkout.
Verify this boundary before publishing Git history or a source archive. Private
recovery bundles and local audit build trees must never be uploaded. Review
Actions logs, artifacts and caches before changing repository visibility; future
CI caches only third-party dependencies. These precautions do not grant rights
to redistribute transformed material or replace the source license conditions.

## Unicode 15.1.0 data

Copyright © 2023 Unicode®, Inc. Unicode and the Unicode Logo are registered
trademarks of Unicode, Inc. in the U.S. and other countries.
Source: https://www.unicode.org/Public/15.1.0/ucd/
Terms: https://www.unicode.org/terms_of_use.html

The generated ranges and normalization data in
`verif/lean/UsdSpec/Unicode/XidTable.lean` and `NormTables.lean` are derived from
that database. They are covered by the [Unicode License V3](licenses/Unicode-LICENSE),
not relicensed by the root Apache license. The permission notice is retained in
associated documentation. Their generators preserve attribution pointers.

The bundled complete Unicode V3 notice is reproduced from the official Unicode
organization's ICU 74.1 source, contemporary with Unicode 15.1:
https://github.com/unicode-org/icu/blob/release-74-1/LICENSE
Only its complete Unicode notice is included, not ICU's unrelated third-party
notices. The original UCD copyright identification above is retained separately.

## Build-time dependencies

Lean, Mathlib, OpenUSD, LightUSD, AOUSD supplemental data and their dependencies
are external checkouts, installations or ignored build inputs. Their licenses
continue to apply. Do not include their binaries or local build/cache trees in
source releases merely because this repository uses them for verification.

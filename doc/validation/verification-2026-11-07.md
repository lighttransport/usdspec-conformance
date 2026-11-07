# Local verification setup — 2026-11-07

The standalone repository now provides `scripts/verify-local.sh` for complete
verification using LightUSD and a separately built local OpenUSD, alongside the
pinned stock OpenUSD wheel. Build products and execution records live in `build/`.

## Environment and coverage

- Lean/Mathlib 4.35.0, with an independent local `.lake` cache. The former cache
  symlink was copied without modifying its external target; the copy has no
  external symlinks.
- LightUSD source: `$LIGHTUSD_ROOT` (the supplied LightUSD checkout), revision
  `68564c9d7d283f55646942506f999ea4bb5863bf`, with existing user modifications.
  Required consumers are freshly built in Debug mode under `build/lightusd`.
- Local OpenUSD source: `$OPENUSD_ROOT` (the supplied OpenUSD checkout), revision
  `372361a1db813e4ca957eedcd6e5209e11c122ed`, with existing user modifications.
  A separate core-only Release build replaces reliance on its stale 26.5 install.
- Stock baseline: `usd-core==26.11`, Python 3.11; validated package/module ownership.
- AOUSD supplemental release 1.0.1, checkout pin
  `c15ae0cad3ed9e07a25dffd6699627d2c166cab0`; Unicode UCD 15.1.0 remains hash-pinned.

Both external working trees retain their existing changes. This work changes the
verification harness, not their implementation sources.

## Harness changes

Full-suite configuration requires the native consumers and external paths.
Checker reflection requires the actual checker when a native build is selected.
Native vector replay, native and Lean combine-chain consumers, and the remaining
supplemental categories are registered in CTest. The Lean label includes Unicode
and negative axiom controls. A vector-copy gate checks the native consumer's
committed input bytes against this repository's canonical artifacts.

Nine `local_*` tests replay the differential cases against the source-built local
OpenUSD. They record checkout provenance independently of stock-wheel results.
Stock tests explicitly select stock mode and clear local library/plugin overrides;
local tests select their own installation. Oracle process failures, invalid JSON,
and invalid schemas fail independently of semantic-difference allowances.

Regression fixtures cover provenance boundaries, dynamically imported oracle
helpers, crashed or malformed oracle responses, and valid native JSON without
an oracle-style status field. Proof-only configuration remains supported.

## Execution records

The setup runner writes `build/verification.log`, `build/results.xml`,
`build/stock-provenance.json`, and `build/local-provenance.json`.
The strict PCP difference ceiling remains 15; passing that gate does not establish
PCP parity. Elimination of the previously documented differences is outside this
setup task.

## Final measurements

`scripts/verify-local.sh` completed successfully end to end. Its final CTest run
passed **37/37 tests, zero failures and zero skips**, in 235.80 seconds (excluding
the initial source builds). All nine local-oracle comparisons passed. Re-running
setup reused the compiled artifacts and verified cached dependencies.

| Check | Measured result |
|---|---|
| Axiom audit | 3,302 theorems, including 512 private helpers, across 44 modules; only standard allowed axioms |
| Generated artifacts | All 20 unchanged; native committed copies agree |
| Native vector replay | 39,091 assertions, zero failures |
| Combine-chain corpus | All 58 cases across 8 files pass in native and Lean consumers |
| Unicode | 19,074 reference rows, 2,380,810 NFC/NFD checks, zero failures; table/negative controls and idempotence sweep pass |
| Reflection | All 16 references resolve; actual freshly built checker dump and compiled Lean environment verified |
| Stock strict composition | 135 compared: 120 matching, 15 differing, no strict allowlist |
| Local strict composition | 135 compared: 120 matching, 15 differing, no strict allowlist |
| Supplemental coverage | Composition plus data-type bridge, 54 file-format assets and 8 value-resolution entries pass |

The source checkout's default Python installation directory was versioned
(`lib/python3.11/site-packages`). The runner explicitly sets
`PXR_PYTHON_INSTALL_DIR=lib/python`, ensuring its isolated prefix is reproducible.
No external implementation edits were necessary. The harness regression checks
include six provenance/import fixtures and four oracle-transport/document fixtures.

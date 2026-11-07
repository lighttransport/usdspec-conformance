# Verification and conformance status

Summary of what is proved, what is checked by execution, and what is open.

Latest local execution: **37/37 passed, zero skips**, including separate stock and
source-built local OpenUSD 26.11 tracks. See
[the 2026-11-07 setup and execution report](validation/verification-2026-11-07.md).
The sections below retain the original split measurements.
Measured at the split from LightUSD (this repo's first import, `cd449a7`;
LightUSD `292a7819d`). The detailed, dated execution ledger is
[`validation/lean-followup-status.md`](validation/lean-followup-status.md); numbers
here must be re-measured after any change (`ctest --test-dir build`).

## 1. Test suite (ctest, standalone)

21/21 pass with a LightUSD Debug build, the stock OpenUSD 26.11 oracle
(`usd-core==26.11`, Python 3.11) and the AOUSD supplemental suite 1.0.1.

| Group | Tests | What it establishes |
|---|---|---|
| Lean proofs | `lean_build`, `lean_test`, `lean_axioms`, `lean_axiom_audit_tests` | Full `UsdSpec` build; kernel/`decide` examples; 3,302 theorems depend only on `propext`, `Classical.choice`, `Quot.sound` (no `sorry`, `native_decide`, `bv_decide`) |
| Generated artifacts | `lean_vectors_check` | 20 generated vector files have no drift from the Lean generators |
| Unicode | `lean_unicode_conformance` | Hash-pinned UCD 15.1.0; independent XID/normalization table generation; four negative trust controls; Lean NFC/NFD against the official 19,074-row corpus and all 1,095,035 scalars outside it; 3.8M-string idempotence sweep; 15,519 table-invariant checks |
| Registry gates | `spec_citations`, `model_split`, `issue_tags` | All 73 findings have valid spec line citations and quoted text found in the cited lines; every finding is classified literal/compat with resolvable Lean declarations; every `SPEC-ISSUE` tag is registered |
| LightUSD reflection | `reflection_table`, `reflection_environment`, `reflection_checker_tests` | The validator's rule-to-Lean table (16 references) resolves to real declarations, also in the compiled Lean environment |
| Differential vs stock OpenUSD | `pcp_json_contract`, `primindex_vectors`, `layerstack_vectors`, `raw_metadata`, `usda_strings`, `usda_keys`, `name_order`, `listop_modes` | Lean-generated or hand-written cases agree between LightUSD and stock OpenUSD 26.11 (prim-index: 256 layered arc-edit cases plus 10 mechanism cases; layer stacks: 94 graphs; PCP JSON: 39 contract tests) |
| AOUSD composition | `aousd_composition` | 138 supplemental composition cases retained; ratchets below |

## 2. Composition conformance (LightUSD vs stock OpenUSD)

| Measure | Result |
|---|---|
| Checked corpus (v1, with allowlist) | 128 exact / 7 allowlisted / 0 unexpected, of 135 structural cases (3 more cases are hash-pinned invalid-text roots with explicit rejection checks) |
| **Strict lossless comparison, no allowlist** | **120 exact / 15 differing**. Ratchet `STRICT_PCP_ORACLE_DIFF = 15`; the goal is 0. **This is not parity.** |

The 7 allowlisted cases (`tests/next/aousd-pcp-allowlist.txt`):
`BasicLocalAndGlobalClassCombination`, `SpecializesAndAncestralArcs2`,
`SpecializesAndAncestralArcs4`, `TrickySpookyInherits`,
`TrickySpookyInheritsInSymmetricBrowRig`, `TrickyInheritsAndRelocates4`,
`TrickySpookyVariantSelectionInClass`.

The 8 additional strict-only differences: `BasicSpecializesAndInherits`,
`ImpliedAndAncestralInherits_ComplexEvaluation`, `SpecializesAndAncestralArcs`,
`TrickyNestedClasses`, `TrickyNestedClasses2`, `TrickySpecializesAndInherits`,
`TrickySpecializesAndInherits2`, `TrickySpecializesAndInherits3`.

Causes fall in implied-class propagation, implied-specialize/inherit ordering and
one variant-selection-in-class case. A blanket "implied specializes first"
reorder was tried and regressed four other cases; a correct rule needs per-origin
grouping of an implied inherit with its implied specialize.

## 3. What the Lean model covers

44 modules under `verif/lean/UsdSpec`: list operations and arc lists, dictionaries,
layer offsets (TCPS), paths and element ordering, Unicode normalization and XID,
crate (integer coding, LZ4 framing, list-op wire format, value reps, path tables,
header), USDA grammar and a parser/printer round-trip for the supported
operational AST, schema families and prim definitions, population (children
order), strength ordering, namespace mapping, relocates, instancing, a toy
prim-index builder, value resolution (metadata, attributes, time samples, clips,
splines with rational error bounds).

Scope limits that matter:

- The prim-index model is a toy: asset resolution, layer offsets and chained
  relocates are abstract or omitted. It covers list edits, payload load policy,
  implied classes (including their own authored arcs), variant selection
  provenance, relocation source suppression and destination mapping, and
  authored-arc/variant-context cycles, with 10 mechanism vectors checked against
  both implementations.
- The USDA round-trip theorems cover the supported operational AST, not the full
  PEG or C++ equivalence. Spline results use rational arithmetic; no
  floating-point rounding bound is asserted.
- Where OpenUSD differs from the literal spec text the registry records both
  (10 findings have separate literal and OpenUSD-compatible Lean declarations).

## 4. Findings registry

73 `SPEC-ISSUE` findings in `verif/lean/ISSUES.md` (60 confirmed, 9
openusd-differs, 3 notes, 1 verified; `model_split` also rejects malformed rows). Each was re-read by an independent reviewer against the spec and its
Lean declaration; no claim was refuted, and citation and wording corrections were
applied. Drafts for upstream reports are in `issues/aousd/08`-`21` (and `01`-`07`);
**nothing has been filed**. Not independently re-verified: LEAN-811, LEAN-812, the
oracle part of LEAN-514, and "clean OpenUSD source" clauses of LEAN-802/804/806/533.

## 5. Open items

1. **General NFC idempotence is not proved.** Only `canonicalOrder_idem` is
   proved; the rest is executed evidence (section 1). Reduction: `nfc(nfc x) = nfc x`
   follows from `nfd(nfc x) = nfd x`. Blockers: kernel evaluation over the tables is
   superlinear (about 5 s for 100 entries, over 2 minutes for 1,000), so the table
   premises need a kernel-friendly encoding, plus a blocking-invariant proof for
   the composition loop.
2. Strict PCP parity: 15 differing cases (section 2).
3. Relationship default authored state: composition and USDA/USDC round trips.
4. Composed-stack relocate error policy and validator rules.
5. Remaining vectors: dictionary, comparator, population, composition, instancing,
   with native consumers.
6. Broader regression coverage (serial/threaded Debug, legacy spline, Python/WASM)
   is owned by LightUSD and not part of this repository's tests.
7. Housekeeping: theorem renames and a few docstring items deferred in the module
   review (see the ledger); `tests/next/test-pcp-json.py`, the supplemental runner
   and its allowlist exist in both this repo and LightUSD and can drift.

## 6. How to reproduce

See the top-level [README](../README.md): `scripts/setup-oracle.sh`, then `cmake`
with `LIGHTUSD_ROOT`, `LIGHTUSD_BUILD_DIR`, `ORACLE_PYTHONPATH`,
`AOUSD_SUPPLEMENTAL_ROOT`, then `ctest --test-dir build -j4`. Tests that need a
LightUSD checkout report a skip (exit 77) rather than a pass when it is absent.

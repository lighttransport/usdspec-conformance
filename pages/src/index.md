# USD Core Specification in Lean 4: formalization and conformance

This site summarizes **usdspec-conformance**: a Lean 4 formalization ("the Lean
model") of the AOUSD *USD Core Specification* v1.1.0, together with differential
conformance tests that replay Lean-generated test vectors against two
implementations, [LightUSD](https://github.com/lighttransport/tinyusdz) and
stock OpenUSD, and a citation-checked registry of specification findings.

An independent project led by Light Transport Entertainment Inc. Not affiliated
with or endorsed by the Alliance for OpenUSD (AOUSD). Source repository:
[lighttransport/usdspec-conformance](https://github.com/lighttransport/usdspec-conformance).

Every page on this site exists in two forms: `.html` (this page: for humans)
and the identical content as raw `.md` markdown at the same path (for AI
agents), e.g. [`index.md`](./index.md).

## Background: why formalize a specification

The USD Core Specification is prose plus normative pseudocode. Formalizing it
in Lean 4 accomplishes three things that plain reading cannot:

- **Precision.** Every normative definition becomes a computable Lean
  definition, and every claim about it becomes a theorem. Ambiguities and
  self-contradictions in the prose surface as (unprovable or negative) results
  instead of silently passing.
- **Mechanical citation checking.** Each finding in the registry is tied to
  exact spec line ranges with quoted text that a CI gate verifies against the
  vendored specification.
- **Machine-generated conformance vectors.** The Lean definitions generate test
  vectors (`tests/next/generated/lean/`) that both LightUSD and stock OpenUSD
  are replayed against, so both implementations are tested against the *same*,
  provenance-tracked data rather than hand-written fixtures.

## The pieces

| Component | Role |
|---|---|
| Lean model (`verif/lean/UsdSpec`, 44 modules) | Machine-checked model of the normative parts of the spec: list operations, dictionaries, layer offsets, paths and element ordering, Unicode, crate (integer coding, LZ4 framing, value reps), USDA grammar/round-trip, schema families, population, strength ordering, composition (incl. a trimmed prim-index builder), value resolution. |
| [LightUSD](https://github.com/lighttransport/tinyusdz) (`src/next`) | The implementation under test; its C++ consumers read the Lean-generated vectors (refreshed from this repository's generators). |
| Stock OpenUSD 26.11 | The conformance oracle (`usd-core==26.11`, hash-pinned), the baseline for differential testing. A separately built local OpenUSD track records fork-compatibility results. |
| AOUSD supplemental composition suite 1.0.1 | Upstream's 138-case composition corpus, used as an additional ratcheted suite. |
| Unicode UCD 15.1.0 | Hash-pinned reference data for XID and normalization gates (official corpus, negative controls, sweeps). |
| Findings registry | 73 `SPEC-ISSUE` findings with citations, classification and reviewer sign-off; drafts for upstream reports live in `issues/`. |

## Current status (snapshot)

Headline numbers at the time of the 2026-11-07 verification (see also the
[Status](./status.html) page, which is the detailed, dated record):

- Lean: full build with **no `sorry`**; 20 generated artifacts with no drift; the
  axiom audit passes for **3,302 theorems** over 44 modules depending only on
  `propext`, `Classical.choice`, `Quot.sound`.
- Latest full local execution: **37/37 tests passed, zero skips** (2026-11-07),
  including stock and source-built local OpenUSD 26.11 tracks.
- Strict lossless PCP comparison against stock OpenUSD 26.11: **120 exact /
  15 differing of 135 composition cases** (ratchet goal: 0). This is **not
  parity**; do not describe it as such.
- General NFC idempotence is **not proved**; the evidence is executed (official
  Unicode corpus, bounded sweep, table-invariant checks).
- Registry: **73 findings** (60 confirmed, 9 openusd-differs, 3 notes,
  1 verified), each re-read by an independent reviewer; nothing filed upstream
  yet.

## AOUSD specification gaps (findings)

Findings by category (numbering bands of the registry; see the
[Spec findings](./findings.html) page for each entry):

| Band | Area | Findings |
|---|---|---|
| 0xx | List operations | 1 |
| 1xx | Dictionaries / layer offsets | 5 |
| 2xx | Paths and element ordering | 9 |
| 3xx | Schema families | 1 |
| 4xx | Crate | 10 |
| 5xx | Composition | 11 |
| 6xx | Population | 5 |
| 7xx | Value resolution | 20 |
| 8xx | USDA grammar | 11 |

Caution with unpublished findings: drafts exist in `issues/aousd/01`-`21`, but
**nothing has been filed** with AOUSD or OpenUSD yet.

## Implementation status: LightUSD and OpenUSD

- **LightUSD** implements the same normative semantics as the Lean model where
  the model was reflected into code (`verif/lean/REFLECTION.md` records the
  rule-to-Lean table; a CTest gate re-checks it against the compiled Lean
  environment). Conformance is measured, not asserted: native consumers replay
  the same vectors, and the strict PCP comparison above bounds remaining
  composition differences.
- **Stock OpenUSD** is kept as an isolated, hash-pinned oracle rather than a
  reference implementation to imitate: where the literal spec text and OpenUSD
  behavior differ, the registry records *both* readings, and 10 findings carry
  separate literal and OpenUSD-compatible Lean declarations.
- Local, source-built OpenUSD results describe **fork compatibility**; the
  pinned stock wheel remains the conformance baseline.

## Explore

| Page | Content |
|---|---|
| [Status](./status.html) | Full verification and conformance status, open items, how to reproduce. |
| [Lean formalization](./formalization.html) | Modules, build instructions, axiom audit, Unicode conformance gates. |
| [Reflection](./reflection.html) | How the model is reflected into LightUSD. |
| [Spec findings](./findings.html) | The 73-entry findings registry (the AOUSD spec gaps). |
| [Verification report](./verification.html) | Latest dated full-suite setup and execution report. |
| [Execution ledger](./ledger.html) | Detailed, dated follow-up and checkpoint ledger. |

Agents: every page above is also served as `./<name>.md`.

# Lean 4 formal verification of the AOUSD Core Spec v1.1.0 (2026-11-06)

`verif/lean/` is a Lean 4 (v4.35.0) + Mathlib (v4.35.0) formalization of the
normative parts of `aousd/core/1.1.0/core_spec.md`. Every definition is
executable; proofs establish the properties the spec claims or the corrected
form when a claim is false. The formalization is reflected into LightUSD
`src/next` through committed test vectors, a structural composition gate, and
validator rules that point at their Lean definition.

## Scope

| Area | Spec | Lean module(s) |
|---|---|---|
| List ops (combine, reduce, chain, congruence), legacy add/reorder | L1271-1708 | `ListOp`, `ListOp/Apply`, `ListOp/Legacy` |
| Dictionaries | L1221-1269, L6200-6236 | `Dict` |
| Layer offsets, time codes per second | L4271-4298, L5428-5510 | `LayerOffset` |
| Paths: elements, ordering, PEG; XID tables; NFC | ch 8, L1805-1837 | `Path/*`, `Unicode/*` |
| Composition: arcs, LIVERPS, namespace maps, relocates, prim index, instancing | ch 10 | `Composition/*` |
| Stage population: child / property ordering | ch 11 | `Population/Children` |
| Value resolution: metadata, attribute priority, time samples, splines, clips | ch 12 | `ValueResolution/*` |
| Schemas: family/version, prim definition | ch 13 | `Schema/*` |
| Crate: header/TOC, ValueRep, integer coding, LZ4 framing, paths, list ops | L11532-12910 | `Crate/*` |
| USDA: full normative PEG (217 rules) + subset parser/printer | L9569-11375 | `Usda/*` |

35 modules, about 13k hand-written lines plus generated tables, over 630 named theorems,
over 240 `example`s. No `sorry`. The initial version used `native_decide` in three modules. The independent
follow-up replaced these with kernel-checked proofs; its full work ledger is
[lean-followup-status.md](lean-followup-status.md).

## Reflection into LightUSD

| Mechanism | Result |
|---|---|
| `tests/next/test_lean_vectors.cc` (ctest `next_test_lean_vectors`) replays 15 committed `.inc` tables from `lake exe usdspec-gen` | about 23k checks, 0 failures after the fixes below |
| `next_test_lean_vectors_combine_chain`: corpus `data_types/tests/combine_chain` (previously only counted) | 58/58 in Lean and C++ |
| `next_usdcat --dump-pcp-json` + `run-aousd-supplemental.py --compare-pcp`: full prim-stack / child / property comparison (previously existence only) | 138 cases: 107 exact, 31 allowlisted with reasons, ratchet 0 |
| Validator: `ValidationRuleMetadata::lean_ref`, 6 new rules, `scripts/check-lean-reflection.py` (ctest `next_lean_reflection_table`) | 7/7 references resolve; no new findings on the corpus except 5 genuine `deprecatedAdd` warnings |
| `next_lean_build` / `next_lean_test` / `next_lean_vectors_check` (when `lake` is found) | proofs build; generated vectors have no drift |

## LightUSD bugs found and fixed

| Bug | Fix | Evidence |
|---|---|---|
| Paths `a.b.c` / `.rel.attr` accepted (multiple property elements) | `c/identifier.c`: at most one property element | pxr `SdfPath` rejects; spec L3449-3450 (LEAN-203) |
| Variant-selection whitespace kept in `Path::Parse` | canonicalized (`/A{ v = x }` → `/A{v=x}`) | spec table L3787; pxr |
| Value-clip time outside `times` returned the boundary *stage* time | returns boundary clip time | pxr 26.11; 188 vector rows; pxr sampled-value diff now 0 timing differences |
| Spline: `post: none` / `none` segments returned knot values; oscillate reflection did not take left limits; knots without `post` parsed as curve | `src/spline-eval.hh`, `types/spline.cc` | pxr 26.11; 34 vector rows |
| Multi-chunk LZ4 writer stored the uncompressed chunk size, unreadable by its own reader | `c/crate-blob.c` stores the compressed size | OpenUSD `TfFastCompression` (LEAN-421) |
| USDA: rejected valid `append foo = [...]` layer metadata and `rel r.default = </a>`; accepted `}}` / `int x = 1 }` on one line, `prepend apiSchemas = []`, `varying` | parser: the two valid forms now parse; the four invalid ones error in strict mode and warn otherwise | pxr `ImportFromString`; usdcat compare 495/0 USDA, 227/0 USDC |

The follow-up fixes LEAN-533 (an unresolved arc does not make an instance),
with one-thread/four-thread regressions. Remaining: 31 corpus composition differences
in `tests/next/aousd-pcp-allowlist.txt` (implied/spooky inherits, relocates,
variant selection, relative-path reference dedup).

## Spec issues

`verif/lean/ISSUES.md` now lists 73 `SPEC-ISSUE` tags, including the
follow-up root-relocation-target discrepancy LEAN-515. Eight original candidate
findings still require the registry-wide follow-up audit. Drafts for upstream review are `issues/aousd/08`-`21`, with
repros in `issues/aousd/08-12-lean-demo/` and `13-21-lean-demo/`. Headline
findings:

- Dictionary combining is not associative (L1243), so the resolution fold order matters.
- `A ≅ B ⟹ reduced(A) = reduced(B)` is false (deleted order is unobservable).
- The §12 layer-offset example applies the offset backwards; the TCPS "stack-level" note gives wrong offsets.
- The USDA PEG as written rejects 103 of 190 real files (keyword-prefix identifiers such as `defaultPrim`, decimals like `1.5`, `.timeSamples`, `customData`, newlines/tabs in strings).
- The path PEG rejects mixed `/`+`{v=x}` paths and `../..`; the element-ordering example cannot be produced by any consistent rule.
- Crate: ValueRep flag bit order, 64-byte bootstrap reserve, two PATHS counts, jump-0 non-termination, integer-coding example typo.
- Specifier bullets overlap/gap; attribute source priority stated three incompatible ways; reference python does not parse.

Nothing has been filed upstream; drafts follow the `issues/README.md` review procedure.

## Reproduce

```sh
export PATH=$HOME/.elan/bin:$PATH
cd verif/lean && lake exe cache get && lake build && lake exe usdspec-test
lake exe usdspec-gen --out ../../tests/next/generated/lean --check
cd ../.. && cmake --build build_ninja/next_debug -j16
ctest --test-dir build_ninja/next_debug -L lean --output-on-failure
ctest --test-dir build_ninja/next_debug -L aousd --output-on-failure
scripts/check-lean-issues.sh
```

# Reflection table: Lean ↔ LightUSD

One row per reflected theorem/definition. "Vectors" are the committed
`tests/next/generated/lean/*.inc` tables replayed by `tests/next/test_lean_vectors.cc`
(ctest `next_test_lean_vectors`).

| Lean | C++ (src/next) | Validator rule | Test |
|---|---|---|---|
| `ListOp.apply`, `apply_nodup`, `combine_wellFormed`, `reduce_wellFormed`, `iterate_combine` (L5), `apply_combine` (L6) | `ApplyStringListOp` layer/prim-spec-storage.cc:352; `ApplyInt64ListOps` :251 | — | `LEAN_LISTOP` vectors (7k rows, both paths); formal `WellFormed` is preserved by composition/reduction and application preserves unique output |
| `ListOp.chain`, `apply_chain` | `ApplyInt64ListOps` over a stack | — | `LEAN_LISTOP_CHAIN` vectors (1.5k rows) |
| `ListOp.applyCpp_eq_apply`, `applyCppInt64_eq_apply` | same | — | proof (Nodup hypotheses) |
| `ListOp.reduce`, `chain` | corpus `data_types/tests/combine_chain` | — | `usdspec-check-corpus` (Lean, 58/58) + `test_lean_vectors --combine-chain` (C++, 58/58), ctest `next_test_lean_vectors_combine_chain` |
| `Crate.encode32`/`decode32`, `decode32_encode32` | `EncodeDeltaU32`/`DecodeDeltaU32` crate/crate-format.cc:608 (C core: c/crate-delta-encode.c, c/crate-int.c) | — | `LEAN_INTCODE` vectors (decoder on all rows; encoder byte-identical on tie-free rows) |
| `LayerOffset.compose`, `compose_assoc`, `apply_compose` | `pcp::LayerOffset::Compose` pcp/namespace-mapping.hh:110 | `core.layer.subLayerOffset` (`LayerOffset.valid`) | `LEAN_OFFSET` vectors (400 rows) |
| `LayerOffset.cumulative` (recursive TCPS, L5466), `lightusd_order_eq_spec` | `AppendLayerAndSublayers` TCPS scaling pcp/cache-layers.cc:312,352 | — | `LEAN_TCPS_CHAIN` vectors: 340 sublayer chains written as USDA, composed by `pcp::ComposeStageFromFile`, leaf sample times compared |
| `ListOp.Legacy.applyLegacy`, `reorder_perm`, `add_not_expressible`, `reorder_not_expressible` | `ApplyStringListOp` added/ordered path, `ApplyStringListOrder` :325 | `core.listop.deprecatedAdd/Reorder` | proof; `add_ne_append` reproduces the REVIEW demo 05 pxr result |
| `Strength.strengthOrder` + spec examples 2–6 | `PrimIndex::GetStrengthOrder` | — | `decide` (Lean side); C++ comparison via `--dump-pcp-json` corpus gate |
| `Dict.merge`, `merge_assoc_of_compat`, `merge_not_assoc` | `MergeWeakerDictionary` composition/composition-merge-helpers.cc:25 | `core.dict.duplicateKey` (`Dict.WellFormed`, USDA and USDC diagnostics) | proof; pxr confirms non-associativity (LEAN-101) |
| `PathGrammar.parsePath`/`printPath`, `parse_print` | `Path::Parse`/`is_valid` prim/path.cc; `lu_is_valid_path_string` c/identifier.c | `core.prim.name` | `LEAN_PATH_VALID` (50 rows; pxr-checked). **Fixed 2 LightUSD bugs**: `a.b.c`/`.rel.attr` accepted (LEAN-203), variant-selection whitespace not canonicalized |
| `UsdSpec.Usda.parseLayer_print`, `parseLayer_print_dictionary`, `parseQuotedChars_quoteString` | `LoadUSDAFromString`, `PrintDictionaryIndented` writer/value-printer.cc, USDA/USDC transports | — (operational subset inverse, not semantic validation) | General nested AST/fuel proofs; `LEAN_USDA_STRING` (40), `LEAN_USDA_KEY` (135), exact native key/value transport plus pinned stock scripts; namespace-key writer quoting fixed. See [constructor audit](../../doc/validation/lean-usda-roundtrip-audit.md). |
| `Schema.parseFamilyVersion`, `versionedMayInherit` | `ParseSchemaFamilyAndVersion` schema/schema-registry.hh:88 | `core.schema.familyVersion`, `core.schema.selfFamilyInherit` | `LEAN_SCHEMA_FAMILY` (18 rows) |
| `Crate.ListOpEncoding.decode_encode`, `spec_roundtrip`, `wireBits_eq_lightusd`, `pxrRead` | `DecodeCrateListOpWire` crate/listop-wire.hh; path/reference/payload/token/string/Int64 consumers in crate-reader-decode.cc | — | `LEAN_CRATE_LISTOP` (8 generated wire vectors): shared decoder, every truncated prefix, reserved bit, exact production writer payloads and production Int64 reader. Additionally 256 generated `LEAN_CRATE_LISTOP_MODE` rows use the separate `pxrRead` compatibility model; all 128 legal headers with empty/populated vectors pass stock tests across six wire types and eight consumers (2,048 cases). |
| `Crate.ValueRep` pack/unpack (bits 63/62/61) | `ValueRep` crate/crate-format.hh:166 | — | `LEAN_VALUEREP` (incl. reps observed in pxr 26.11 files) |
| `ValueResolution.TimeSamples.eval` (held/linear/blocks/clamp) | `AttributeEval::EvalWith` eval/attribute-eval.cc | — | `LEAN_VR` (218 rows, USDA → stage → eval) |
| `UsdSpec.Spline.keepRatioScale_safe`, `Seg.keepRatio_safe`, `UsdSpec.Spline.Bounds.keepRatio_root_unique`, `keepRatio_value_error` | types/spline.cc → shared src/spline-eval.hh, c/spline.c (floating-point implementation; rounding equivalence separate) | — (analytical model guarantees) | Arbitrary-fuel rational safety and real-root error proof; existing exact `LEAN_SPLINE` vectors and 10 legacy spline tests. See [proof scope](../../doc/validation/lean-spline-bounds-audit.md). |
| `UsdSpec.Unicode.isXidStart`, `isXidContinue`, `Norm.nfcCps`/`nfdCps` | src/unicode-xid-c.c ranges independently checked against pinned official Unicode 15.1; authored paths remain unnormalized | identifier syntax uses XID; no normalization rule is imposed | `next_lean_unicode_conformance`: both generated tables/native parity, four negative trust controls, 2,380,810 official NFC/NFD checks; general symbolic idempotence remains open. |
| `Composition.NamespaceMap`, `Relocates.validRelocates` | pcp/namespace-mapping.hh, `BuildStackRelocates` pcp/cache-layers.cc:84-249 (coverage list in Relocates.lean header) | component rules registered: identity/root/ancestor/below/uniqueness/nested sources plus explicitly named OpenUSD compatibility predicates | proofs; corpus `--compare-pcp` gate |
| `Strength.strengthOrder`, `PrimIndex` toy composition | `Cache::GetPrimStack` (new), `PrimIndex::GetStrengthOrder` | — | `next_usdcat --dump-pcp-json` + `run-aousd-supplemental.py --compare-pcp` (138 retained cases: 3 verified invalid roots + 135 structural; v1 128 exact / 7 allowlisted / 0 unexpected; strict lossless oracle 120 exact / 15 differing, zero ceiling unmet) |
| `UsdSpec.Composition.PrimIndex.mergeArcOpinions_eq_foldr`, `composeWithLoadPolicy` | production PCP arc-field merging and global payload policy, via lusdcat | — | `prim-index-vectors.json`: 256 Lean-composed layered cases, 512 prim/property queries; native and pinned stock parity. Selective loading/cycles/relocates and full model equivalence remain open; [scope audit](../../doc/validation/lean-prim-index-audit.md). |
| `UsdSpec.Composition.PrimIndex.layerStackVisit_mem`, `layerStackVisit_excludes`, `layerStack_mem_known`, `layerStack_fuel_independent` | AppendLayerAndSublayers in pcp/cache-layers.cc; Cache::Open diagnostic overload | — (typed SublayerCycle/InvalidAssetPath PCP diagnostics) | Finite-set termination and exclusion proofs; `layer-stack-vectors.json` 94 native/stock graph/error cases, including repeated legal diamonds and depth 25; API warning/strict tests. |
| `PrimIndex.expandAvailable`, `composePrimIndexChecked`, `Strength.nestedSpecializes_sibling_order` | PCP authored-arc expansion and `PrimIndex::GetStrengthOrder` | — | Finite active-site termination, surfaced cycle diagnostics, self-reference theorem; nested specializes A/B/D/C order matches native PCP and stock OpenUSD 26.11. Native PCP coalesces duplicate specializes classes by subtree mapping and inherit classes only for exact full-map identity; stock-backed class-diamond test and class-coalescing checkpoint improved strict corpus 100/135→110/135; subsequent relocate fixes bring the current baseline to 120/135 (15 differences remain). Implied class own arcs, mapped inherit-diamond identity, relocates and variant-context identity remain open; [scope audit](../../doc/validation/lean-prim-index-audit.md). |
| `PrimIndexInvariants.sitesTree_extendTree`, `impliedCopyTrees_allImplied`, `selFrom_eq_selSource`, `selSource_append_of_some`, `pruneTrees_sites`, `expandAvailable_cycle` | PCP ancestral extension, implied-class flagging, variant selection strength and relocate-source suppression | — | Proved structural invariants of the toy builder; `prim-index-mechanism-vectors.json` (10 Lean-composed implied-inherit, implied-chain, relocate source/destination, variant-cycle, payload-deferral and variant-selection cases; `composeImplied` expands arcs authored at implied class sites) matches native PCP and stock OpenUSD 26.11. The vector exposed and fixed a toy defect: variant-set names are now unioned across layers (they previously duplicated the variant node). `composeRelocated` suppresses relocated-away prims and source-path nodes (`composeRelocated_away`, `composeRelocated_nil`); `composeAtDestination` gives a relocation destination its own opinions followed by the source's arc-derived opinions (chained relocates unmodeled). |
| `Population.listOrderedPrimChildren` | `ComposeChildNames` pcp/cache-opinions.cc | — | corpus "Child names" via `--compare-pcp` |

The follow-up adds exact declaration resolution through `--lake`, including
negative namespace tests and a required checker-binary gate in CI. Corrected
legacy-operation references name `UsdSpec.ListOp.applyLegacy`; a module filename
does not introduce a `Legacy` namespace. `mostCommon_spec`/`mostCommon_mem` and
`Lz4.greedyBlock_endRulesOk` are general proofs, beyond the existing byte vectors.

The operational AST inverse is a theorem of the Lean model. Native transport
vectors and the stock oracle test implementation reflection; they do not prove
general equivalence of the C++ parser and the Lean parser.

Relocate rule references are component-scoped: `OkSame`, `OkRootOpenUsd`,
`OkAncestor`, `OkBelow`, `OkSourcesUnique`, `OkTargetsUnique`, `OkAncestral`,
`OkOtherSourceOpenUsd`, and `OkTargetNamespaceOpenUsd`. The uniqueness split is
proved equivalent to literal `OkOneToOne`. Compatibility predicates do not
replace literal `OkSame` or `OkBelow`; raw local authoring validation does not
model layer-strength selection of contributing relocate opinions.

## Generated C (`lspec_*`, lightusd-c)

Lean → generated C via `tools/lean2c.py` (curated lowerings in
`tools/templates/`), verified C → Lean via vendored MiniC
(`verif/lean/UsdSpecC/` + `tools/c2lean.py`). Generated files are DO NOT EDIT
in `lightusd-c/src/internal/lusd_spec_*.c`.

| Lean | Generated C | Test |
|---|---|---|
| `Crate.mostCommon`, `encode32`/`decode32` (T1) | `lspec_crate_*` | `test_lightusd_spec` crate cases incl. I3 spec example; `tools/cdiff.py` (ASan, incl. MiniC 3-way for `most_common`/`contains`) |
| `ListOp.apply/combine/reduce/iterate` Int64 (T2) | `lspec_listop_i64_*` | `test_lightusd_spec` L1455 combine + apply/reduce; `tools/cdiff.py` |
| `Dict.merge` flat leaf (T2, uint32 token keys) | `lspec_dict_*` | `test_lightusd_spec` spec examples L6208-6236 |
| `LayerOffset.valid`/`sanitize` (T2, comparison-only) | `lspec_offset_valid`/`sanitize` (compose/apply f64 numeric-only) | `test_lightusd_spec` valid/sanitize/compose/apply |
| `ValueResolution.TimeSamples.eval` held + integer-linear (T3) | `lspec_ts_held_eval`, `lspec_ts_linear_eval_i64` (double linear is numeric-only) | `test_lightusd_spec` held/linear/block; `tools/cdiff.py` |
| `Usda.scanQuoted/quoteString` fuel inverse (T3) | `lspec_quote_len`/`lspec_scan_quoted`/`lspec_quote_string` | `test_lightusd_spec` roundtrip; `tools/cdiff.py` |
| `Unicode XID` full Unicode 15.1 (667+776 ranges) | `lspec_is_xid_*` via `tools/gen_xid.py` (numeric-only; MiniC table support next) | `test_lightusd_spec` edge spots; `gen_xid --check` drift |
| Vendored proof rules | `UsdSpecC/Logic.lean` + `Hoare.lean` + `Splice.lean` (`EvE/ExS`/`Triple`/byte-range algebra) | `lake build UsdSpecC` |
| MiniC differential driver | `UsdSpecC/CDiff.lean` (`usdspec-cdiff` exe): `most_common`/`contains`/`crate_enc`/`crate_dec`/`listop_apply`/`listop_iterate`/`listop_reduce`/`listop_combine`/`dict_merge`/`dict_lookup`/`ts_held_bits`/`ts_linear`/`scan_quoted`/`quote_len`/`offset_valid`/`offset_sanitize` | `tools/cdiff.py` 3-way (`C == MiniC == Python-Lean` for scalars/listop/dict/ts/scan/offset; `C == MiniC` for crate bytes) |
| First Hoare proof | `UsdSpecC/Proofs/Pack.lean` (`pack_byte_exs`/`pack_byte_call`: `lspec_crate_pack_byte` returns `(a&3)|(b&3)<<2|…` as `u8`, terminates, mem untouched) | `lake build UsdSpecC` |
| Contains loop invariants | `UsdSpecC/Proofs/Contains.lean` (`ContainsFacts`, `step_eval`, `cond_eval` `i<n`, `body_eq_eval` `xs[i]==v`, `loop_exs` fuel induction `n-i` + `contains_call` whole-function via preamble/loop/final-`ret 0` and `callFunc_of_ExS`) | `lake build UsdSpecC` |
| Dict-contains loop invariants | `UsdSpecC/Proofs/DictContains.lean` (`DictFacts`, stride 4, `u32` keys, `dict_loop_exs` + `dict_call` whole-function) | `lake build UsdSpecC` |
| Delta-codec common + 1-byte tail | `UsdSpecC/Proofs/Encode.lean` (`enc_eq_eval`/`toInt_i32_inj`, `encode_delta32_common_body` via `seq_ret`, generalized `encode_byte1_exs` store fragment `mem' = mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))` via `store_int`, `enc_ge_eval`/`enc_le_eval` guards, `encode_delta32_call` whole-function code-1 via `callFunc_of_ExS`) | `lake build UsdSpecC` |
| Delta-codec 2-byte tail | `UsdSpecC/Proofs/Encode.lean` (`and255_mod`, `evalShr8`, `encode_byte2_exs` two-byte store postcondition via `splice_append`/`encodeLE2_eq`, `enc_ge16_eval`/`enc_le16_eval` guards, `encode_delta32_call2` whole-function code-2) | `lake build UsdSpecC` |
| Delta-codec 4-byte tail (code 3) | `UsdSpecC/Proofs/Encode4.lean` (`evalShrU` u32 shr by `k<32`, `evalBand255` low-byte mask, `encodeLE4_eq2el`, `foldPair`/`foldPair4`/`splice_bytes4` four-adjacent-u8-writes composition, generalized `encode_byte4_exs` store fragment postcondition `mem' = mem.upd b (splice blk 0 (encodeLE 4 d))` via `store_int`, `encode_delta32_call3` whole-function code-3 via guard-skip + `callFunc_of_ExS`) | `lake build UsdSpecC` |

Drift gates: `python3 tools/lean2c.py --check`, `python3 tools/gen_xid.py --check`,
`python3 tools/c2lean.py --check` (requires `clang`, LP64/LE),
`lake build UsdSpecC usdspec-cdiff`, `ctest -R test_lightusd_spec`.

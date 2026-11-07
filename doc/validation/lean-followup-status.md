# Lean review and conformance follow-up

> **Moved.** This ledger was written in the LightUSD `large-scene` branch
> (through commit `dd4478132`) and now lives in `usdspec-conformance`. Paths such as
> `src/next/...`, `build_ninja/...` and `tests/next/...` in older entries refer to
> the LightUSD tree; the Lean, `tests/next/` Python and `scripts/` paths are now
> relative to this repository.


This is the execution ledger for the accepted full-closure plan. An unchecked
item is incomplete; passing a narrower test does not close it.

## Formalization

- [x] Semantic review of the 73 registry findings (2026-11-07): four independent read-only reviewers re-read the cited spec lines and the named Lean declaration for every row. Result: no claim was refuted; the rows with wrong or off-by-a-few citations, or overstated/loosely worded claims, were (LEAN-112/201-207/411/412/413/501/512/513/514/515/601-605/702/745/764/769/533/807/808), all corrected in `ISSUES.md` (and two Lean comments), then re-gated by `check-lean-spec-citations.py`. Not independently re-verified by the reviewers: LEAN-811 and LEAN-812 (carry the earlier stock-OpenUSD confirmation), the oracle clause of LEAN-514, and "clean OpenUSD" source clauses of LEAN-802/804/806/533 that depend on files outside this checkout.
- [x] Per-module review of the 34 hand-written Lean modules (generated tables excluded), by four independent read-only reviewers (2026-11-07). No module over-claimed materially or contained an unsound theorem; findings were stale citations (corrected), stale "still open" headers in the Usda proof files (corrected), and over-promising docstrings (`eval_clamp`, `template_identity`, `postSlope_linear_extends`, `nonRegressive_iff`, `Shares`, the Legacy `add`/`append` sufficiency, SplineBounds' Keep Ratio scope, ValueRep and ListOpEncoding coverage) which were reworded. Deliberately NOT applied (cosmetic or API-affecting): renaming theorems (`eval_clamp`, `template_identity`, `postSlope_linear_extends`, `relocated_source_not_present`, `parseLayer_print_dictionary`), dropping the tautological `parse_print_unversioned`, deleting the `Core/ListLemmas` stub, and a note that `Lz4.unframe` reads the chunk count unsigned. Gates after the edits: Lean build, 20-artifact drift check, axiom audit (3,302 theorems), reflection 16/16, issue tags, citation and model-split gates.
- [x] Mechanical `SPEC-ISSUE` registry coverage: all 73 registry IDs are unique,
      every ID has a Lean source tag, and no tagged ID is absent from the registry.
      This checks coverage only; source citations and claim validity still need
      the semantic review below.
- [x] Separate literal and OpenUSD compatibility models and expectations: every registry row is classified in `verif/lean/data/model-classification.json` (10 dual literal/compat declaration pairs, 7 compat-observation rows naming the implemented side, 53 spec defects, 3 notes); `scripts/check-lean-model-split.py` is a CTest/CI gate with a negative control. Observation rows keep a single Lean model plus the stock probe in the registry.
- [x] Prove tokenizer injectivity and element-name comparator equality/order laws for arbitrary character lists and strings.
- [x] Remove the strength comparator depth cap and prove unbounded ordering.
- [x] General decoded-row PATHS tree round trip, sufficient/tight-chain fuel bounds, all jump forms and sparse index preservation (binary table bounds/uniqueness remain separate validation work).
- [x] General supported operational USDA AST parser/printer round trip and escaping, including arbitrary dictionary keys and actual input-length fuel (see lean-usda-roundtrip-audit.md; full PEG and semantic validation remain separate).
- [ ] General NFC idempotence — **accepted as documented open by user decision (2026-11-07)**; not proved. Evidence: 19,074-row corpus + 1,095,035-scalar complement, 3.8M-string idempotence sweep, 15,519 table-invariant checks (composite decomposition, decomposition stability, Hangul round trip), proved `canonicalOrder_idem`. Blocker spike: kernel evaluation over the tables is superlinear (100 composition entries ~5 s, 1000 > 2 min; kernel array indexing is O(n)), so the table premises need a kernel-friendly re-encoding plus a `composeGo` blocking-invariant proof.
- [x] Pinned independent Unicode/XID provenance, official normalization conformance and negative trust gates (Unicode 15.1.0).
- [x] Characterize mostCommon, empty input, and ties.
- [x] Prove greedy LZ4 end rules for arbitrary supported inputs.
- [x] Spline rational-model Keep Ratio validity and real-root bisection value-error bounds (arbitrary fuel; see lean-spline-bounds-audit.md; native floating-point rounding remains separate).
- [x] Expand prim-index model (toy-model scope): list edits, payloads (LoadAll/LoadNone), implied classes that expand their own authored arcs (`composeImplied`), variant selection provenance, relocation source suppression and destination mapping (`composeRelocated`, `composeAtDestination`; chained relocates not modeled), and authored-arc/variant-context cycles. Invariant theorems in `PrimIndexInvariants.lean`; 10 generated mechanism vectors match native PCP and stock 26.11. The model remains a toy: asset resolution, offsets and relocation chains are abstract/omitted.
- [x] Remove native_decide proof dependencies and audit compiled theorem axioms, including private declarations (semantic assumption audit remains in the module review).
- [x] Resolve eight original candidate findings: 414/767 fixed; 501/801/804 verified notes; 311/802/746 confirmed. Registry-wide citation and coverage audit remains part of the open module review.

## Implementation

- [x] LEAN-533 contributing direct arcs: implementation, regression, key/filter parity.
- [ ] Close all parseable composition differences: implied classes, arc ordering,
      variant selection, relocates, cycles, property conflicts, anchored dedup.
- [x] Instance-proxy stacks omit ignored local opinions (direct query regression).
- [x] Shared OpenUSD-compatible comparator and separate PCP/stage ordering.
- [ ] Relationship default authored state, composition, USDA/USDC round trips.
- [x] Local unknown-metadata assignment folding across layer/prim/variant/property scopes (cross-layer schema-defined semantics remain separate).
- [x] Reject qualified None across references/payload/inherits/specializes,
      preserving explicit clears; 48 profile/field/qualifier cases pass.
- [x] Shared crate list-op wire decoding and production-path vector consumer.
- [ ] Complete relocate checks and validator rules with accurate Lean links (local authoring components are implemented/reflected; composed-stack/error policy remains open; shared relative-path anchoring is implemented and tested).
- [x] USDC duplicate dictionary diagnostics, order-name recommendation validation, spec version 1.1 (including checker help).
- [x] Workflow fixtures pass strict parsing, including newly exposed C/C++ fixtures.
- [x] Preview explicit linear colorspace and decode/cache identity regression.

## Validation and reports

- [x] Lossless PCP JSON v2, v1 remains default; ordered duplicate-layer stacks.
- [x] Pinned stock OpenUSD oracle and strict ordered comparison.
- [x] Three invalid text cases get explicit rejection tests and available original crate coverage.
- [ ] Zero engine allowlist entries; retain all 138 cases.
- [ ] Dictionary/comparator/population/composition/instancing vectors + consumers.
- [x] Exact Lean reflection resolution, negative tests, required checker gate.
- [x] Independent REVIEW verdicts and polished drafts for 08–21; duplicate search.
- [ ] CI proofs/runtime/drift/reflection/vectors/strict PCP, cached pinned deps.
- [ ] Full Debug serial/threaded, supplemental values/composition, checker,
      native round trips, legacy spline, affected Python/WASM regressions.
- [ ] Documentation/reflection matrix updated with measured results.

## Constraints

Preserve unrelated work. Issue drafts/repros remain ignored and local. Do not
file reports or push. Spec text stays byte-identical. Final compatibility
claims require stock OpenUSD provenance; the local fork is preliminary evidence.

## Follow-up evidence

- Official `usd-core==26.11` wheel is isolated under the ignored
  `build_ninja/stock-openusd-oracle/site-packages`; provenance is beside it.
- Both issue repro scripts pass against the stock wheel; 14 ignored local
  REVIEW files retain individual findings, edits, and duplicate-search evidence.
- The 10 legacy spline tests pass in `build_ninja/legacy_debug`.
- Lean proofs and runtime pass, and all 15 committed vector tables have no drift.
- C++ production tests cover USDC duplicate keys, diagnostic byte locations,
  and strict-reader rejection. The duplicate-key rule preserves last-value behavior.
- New LEAN-515: OpenUSD allows root-prim relocate targets. Do not implement
  the handoff's proposed target rejection: it would violate the chosen
  compatibility target. Literal and compatibility root predicates are separate.
- CI now covers proofs/runtime/drift/vectors and mandatory checker reflection;
  the strict lossless PCP portion still needs implementation.

## Checkpoint (2026-11-06)

- Full standalone Debug CTest: **96/96 pass**, including all eight Lean gates
  and both former preview/workflow failures. Log: `/tmp/lean-green-native-tests.log`.
- Supplemental structural baseline remains **105 exact / 33 allowlisted / 0
  unexpected**, with the existing property-order relaxation still present.
  Log: `/tmp/lean-composition-regression.log`; this does not close composition.
- Required checker plus compiled Lean reflection passed, as did namespace
  rejection tests. CI YAML parses; the hosted workflow has not been executed.
- Full legacy unit CTest was launched after the ten spline tests passed. It
  remains live under exec session 52808; poll that handle rather than restart.
  Output: `/tmp/lean-legacy-unit-tests.log`.
- Final warm Lean build/runtime/drift check after the new LEAN-515 predicate
  passed. Logs: `/tmp/lean-checkpoint-{proof-build,runtime,drift}.log`.

Remaining work retains the full accepted plan: general PATHS/USDA/NFC/comparator
proofs; richer prim-index and spline guarantees; registry-wide semantic audit;
composition allowlist closure and strict lossless oracle; relationship defaults,
unknown metadata list ops, crate list-op reflection, relocate/order rules;
remaining vectors, threaded/Python/WASM and wider round-trip gates.

## Anchored arc identities

References and payloads now compare anchored asset identifiers for prepend,
append, add, delete, and reorder, while retaining authored strings and layer
tags for expansion/payload policy. Identifier resolution is memoized within
each merge. The two relative-path corpus cases XPASSed and were pruned from
the engine ledger: **107 exact / 31 allowlisted / 0 unexpected**. Focused
regressions also exercise anchored delete/reorder through separate authoring folders.

The anchored prepend/delete/reorder regression now passes for references and
payloads, using real separate folders. Post-anchor full CTest passed 96/96; output
`/tmp/lean-post-anchor-native-tests.log`.
The full legacy unit run (52808) is still live and must not be restarted.

Qualified `None` was independently probed against the official wheel for every
arc field and qualifier. The final parser change passed the full suite again: **96/96**, log
`/tmp/lean-checkpoint-all-tests.log`. The corpus also passed at **107 exact /
31 allowlisted / 0 unexpected**, log `/tmp/lean-checkpoint-corpus.log`.
Subsequent fixture-only corrections use newlines after nested prims (verified
against stock OpenUSD); the three affected test executables pass again in
`/tmp/lean-stock-fixture-tests.log`.

All full-scope work remains active. The broad legacy unit test is still live
under handle 52808 as of the latest poll; do not restart it because its output
is buffered. The ten focused legacy spline tests already passed.

## Lossless PCP checkpoint

The full legacy unit CTest completed successfully (1013.19 s), in addition to
the ten focused spline tests. Earlier live-session notes above are superseded.

PCP JSON v2 and a pinned stock `usd-core==26.11` Pcp API oracle now preserve
ordered repeated-layer prim/property sites. The original v1 default remains
unchanged. Initial lossless corpus comparison found **60 exact / 78 differing**
cases, while v1 remained **107 exact / 31 allowlisted / 0 unexpected**. The new
comparison has no engine allowlist and fails by default on any difference;
these results do not establish conformance. Variant provenance repair is in
progress, with a cross-host selection/empty-option regression under development.

Variant stack diagnostics now merge the parser's inline/content representation
of one authored variant node and scope empty-option records by the mapped host.
They preserve real repeated specs from distinct reference offsets. Descendant
queries use the same instance source policy as stage traversal. Property stacks
filter opposite property kinds while retaining value-type conflicts. v2 keeps
external relative layer paths instead of collapsing equal basenames.

Eight focused CLI/comparison tests pass with the pinned stock oracle, covering
v1 stability, repeated layers/sites, per-host and empty variant selections,
reference offsets, instance/non-instance descendants, property-kind conflicts,
and external layers with equal basenames. The last completed corpus run reached
**110 exact / 28 allowlisted / 0 unexpected** in v1 and **82 exact / 56 differing**
in strict v2. Three newly matching v1 entries have been pruned. Final post-prune
native/corpus runs are in progress; the strict v2 gate remains failing.

Lean build, runtime and all 15 vector drift checks passed again. Registry check
passed for 73 tags; reflection namespace tests and mandatory compiled/checker
resolution passed (7/7). Literal `native_decide`, `sorry`, and explicit `axiom` declarations were removed
from `UsdSpec/`; the full environment audit subsequently found generated
`bv_decide` axioms, so the trust/assumption audit remains open.

Post-prune corpus rerun confirms **110/28/0** (v1, no XPASS) and **82/56**
(strict v2); log `/tmp/lean-final-lossless-corpus.log`. The strict lossless gate
correctly fails. The earlier native run was interrupted by relinking one test
executable and newly passing allowlist entries; it is superseded by the clean
post-build run at `/tmp/lean-final-lossless-native.log`.

Final post-build standalone Debug CTest passed **97/97** in 224.13 s,
including serial/threaded PCP, all Lean gates, supplemental legacy ratchet,
preview and workflow checks. Log: `/tmp/lean-final-lossless-native.log`.
Session 51272 is terminal. Full plan remains active; strict v2 remains 82/56.

## Invalid text classification

The parser now rejects variant selections in composition-arc target paths and
both relocate paths at layer/prim scope, including arcs authored inside variants.
This applies in both parser profiles and preserves literal braces in asset names.
The native regression exercises 96 arc/profile/qualifier/context cases and eight
relocate/profile/scope/direction cases, plus two positive asset-name checks.
Eleven PCP/oracle contract tests pass, including independent stock rejections,
changed-fixture rejection, and incomplete-corpus rejection.

The three pinned negative corpus roots now require matching diagnostics and
text hashes via `tests/next/aousd-invalid-text.json`. The release contains no
original binary roots for them; all six existing binary dependency layers are
hash-pinned required loads in both LightUSD and the optional stock oracle.
Their old ORACLE-PARSE allowlist entries are removed. Full corpus result:
**138 cases = 3 verified text rejections + 135 structural cases**; v1 has
**110 matching / 25 allowlisted / 0 unexpected**, strict v2 has **82 matching /
53 differing**. The latter still fails at ceiling zero. Output:
`/tmp/lean-invalid-text-corpus.log`. Full native regression is in progress.

The harness now also requires all 138 pinned composition case descriptors and
all three reviewed negative case directories before selecting optional cases.
A missing descriptor is a hard error rather than reduced reported coverage.

Invalid-text follow-up final native result: **97/97 passed**, 232.99 s,
`/tmp/lean-invalid-text-native.log`. Session46737 is terminal. This includes
serial/threaded PCP, supplemental negative classifications and binary loads,
Lean gates, preview and workflow checks. The subsequent focused stock-oracle
contract run passed 11 tests, including the final case-count integrity check.
The full goal remains active; strict v2 still has 53 differences.

## Child-order prefix correction

Layer finalization now uses the shared Sdf run-preserving ordering helper:
`x,a,b` reordered by `b,a` produces `x,b,a`, rather than `b,a,x`. A stock-oracle
contract covers both prim children and pseudo-root order; all 12 focused tests
pass. The full composition-order item remains open: the reference counterexample
in `/tmp/lean-child-raw-order` proves that applying order before source merging
loses raw authored order. Full corpus counts remain 3 negative roots plus 135
structural cases, v1 110/25/0 and strict v2 82/53. Native full rerun is in progress
at `/tmp/lean-order-prefix-native.log`.

Child-order prefix follow-up native verification: **97/97 passed**,
220.60 s, `/tmp/lean-order-prefix-native.log`. Session84280 is terminal.
Final stock-oracle run passed all 12 tests, including explicit pseudo-root
order comparison (4.449 s). Full ordering/composition work remains open.

## Raw authored order and relocation nodes (in verification)

Layer finalization now preserves authored hierarchy index vectors. Stage root/
child queries, indexed child access and traversal use non-mutating ordered
views. PCP applies restatements after each spec's raw names join the weaker
result. C++ namespace tests check raw vectors, traversal, indexed queries,
clone/move, metadata edits, child addition/removal and round trips. Stock
contracts cover USDA/USDC, multiple layers and more than 32 children.
`BasicListEditing_root` matched in v1 and strict v2 and was pruned.

Relocations now operate at the contributing node, before its local children:
renames retain position, collisions preserve an existing target, and cross-parent
arrivals append in lexical order. Root arrivals also precede local root names.
Prohibited names are filtered after composing reference branches, avoiding loss
when both branches relocate a common child to different targets.

A new stock comparison additionally exposed an existing stack-identity alias:
`FlowsThroughRelocateSource` excluded an arrival's own source by path alone.
The exclusion now requires the relocating layer stack too. Verification of this
last correction is in progress. Do not treat the intermediate 16-test run or
its corpus counts as final: the 17th case caught the alias and remains the gate.

The raw-order corpus checkpoint was v1 111/24/0, strict v2 83/52. The first
node-relocation run reached v1 115/20/0, v2 85/50 but revealed a missing-child
regression inside one already-allowlisted case. That regression was corrected;
the specific `RelocatePrimsWithSameName_root` case then matched v1 and strict v2.
Five further CHILD-ORDER entries were pruned based on those matches. A full
post-identity run is still required before reporting final counts.

Final node-order validation: **97/97 native tests passed**, 219.94 s,
`/tmp/lean-final-node-order-native.log`. All **17 stock-oracle contract tests
passed**, 7.952 s. Full corpus retains **138 = 3 verified negative roots + 135
structural cases**: v1 **116 matching / 19 allowlisted / 0 unexpected**, strict
v2 **86 matching / 49 differing**. No newly differing strict cases relative to
the raw-order baseline; three strict cases closed. All six earlier CHILD-ORDER
entries are now removed. Log: `/tmp/lean-final-node-order-corpus.log`. Strict v2
still fails at the required zero ceiling. Native/corpus sessions are terminal.

The full compiled axiom audit initially caught **52 native axioms generated by
bv_decide**, superseding the earlier representative-only result. All 20 tactic
sites have now been replaced without weakening theorem statements: byte joins
and packed fields use universally quantified per-bit equality; signed integer
narrowing uses range hypotheses and `Int.bmod` lemmas. The abandoned LRAT frontend
was replaced by the kernel-checked `UsdSpec/Core/BvKernel.lean` helpers.

The full audit now **passes for 2,475 theorems (323 private) in 33 modules**, with
only `propext`, `Classical.choice`, and `Quot.sound`. Full `lake build`, runtime
suite and all 15 committed-vector drift checks pass. The audit and imported-module
positive/negative regression tests are registered in CTest and CI. This closes
the compiler-trust dependency gap; the broader semantic/hypothesis audit remains
open, so the combined checklist item above remains unchecked. Logs:
`/tmp/lean-all-axioms-audit.log`, `/tmp/lean-kernel-full-build.log`,
`/tmp/lean-kernel-runtime.log`, `/tmp/lean-kernel-drift.log`.

The final imported-module axiom regression suite passes **6/6**, including an
unused explicit axiom and a private-helper positive case. CTest's compiled audit
passes; its repaired regression test passes **1/1** (timing in
`/tmp/lean-kernel-ctest-negative.log`). Required checker reflection remains **7/7**,
and issue registry validation remains **73 tags**. Full native 97/97 is the
preceding implementation baseline; no full native rerun is claimed for the two
newly registered proof-only audit gates.

## Variant option arc provenance

Arcs authored on a selected variant option now retain that option's synthetic
variant node in their persisted source chain. Descendant expansion can therefore
recognize ancestral variant contributions and place them before the descendant's
direct references. This repairs composition order, not just JSON reporting.
The new three-level nested variant regression checks complete ordered stacks
against the stock 26.11 oracle; all **18 contract tests pass**, 8.680 s.

The full 138-case corpus retains **3 verified invalid roots + 135 structural
cases**. Legacy v1 improves to **118 exact / 17 allowlisted / 0 unexpected**;
`TrickyNestedVariants_root` and `BasicVariantWithConnections_root` are pruned.
Strict v2 improves to **88 exact / 47 differing**, with no newly differing cases.
The strict cases closed are `TrickyNestedVariants_root` and
`TrickyInheritsInVariants2_root`; BasicVariantWithConnections still differs in
property-name order. Zero strict differences remains required and unmet.

The 99-test native sweep passed **98/99**; its sole failure was the now-pruned
XPASS entries. The supplemental gate then passed **1/1**, 13.60 s. All 99 tests
have passing results across the sweep and focused rerun, including both new axiom
gates and serial/parallel PCP tests. Logs: `/tmp/lean-variant-origin-{build,
contract,corpus,native,supplemental}.log`. No build or test session remains live.

Next property-order investigation: raw authored interleaving of relationships
and attributes is currently lost in PrimSpec (attributes use property slots,
relationships use unordered maps). GetPrimStack reconstructs attributes then
sorted relationships, which cannot reproduce Pcp's weakest-first authored union.
Preserve raw authored property children through parser/mutations/clones/crate
reader, keeping the separate stage-order view. Do not sort PCP output to hide it.

## Raw property-child order

PrimSpec now preserves raw attribute/relationship interleaving independently of
sorted lookup slots and metadata `propertyOrder`. Adding attributes and
relationships, removing/re-adding them, finalization and deep clones preserve
that sequence. The crate reader consumes its natural `properties` /
`propertyChildren` field without synthesizing metadata. GetPrimStack reports
these raw names for Pcp's weakest-first union. New native tests cover sorting,
cloning and mutation; a stock-oracle contract checks mixed property kinds.
Relationship removal now also removes edit-only/opinion-only records and flags.
The added cold vector's capacity is included in memory accounting.

Full native **99/99 PASS**, 84.62 s; stock-oracle contracts **19/19 PASS**, 9.876 s.
Corpus remains **138 = 3 verified invalid + 135 structural**: v1 **118 exact /
17 allowlisted / 0 unexpected**, now no order-only property differences. Strict
v2 improves to **91 exact / 44 differing**, with no newly differing cases.
`BasicVariantWithConnections_root`, `ErrorInvalidPreRelocateTargetPath_root`,
and `TrickyListEditedTargetPaths_root` now match strictly. Zero ceiling still
fails, as required. Logs: `/tmp/lean-property-order-{build,final-build,native,
contract,corpus}.log`. All sessions are terminal.

This does not close the entire ordering requirement: audit raw order through
USDA/USDC writer round trips and inline PrimVariantData records (their attribute
vector and relationship map remain separate), and finish the shared comparator
and separate stage presentation-order work. The crate writer's `properties`
field currently follows emitted spec order; it must consume preserved order
when completing round trips. Also consider avoiding order-vector allocation on
canonical attribute-only prims that already have unrelated cold data.

## Property order through variants and writers

The raw sequence now also lives on inline PrimVariantData, is copied by its
iterative clone helpers, counted in memory accounting, and transferred to crate
variant holders. Property names include inline defaults, relationships and
content-backed metadata/time-sample attributes in their original interleaving.
USDA writing preserves that sequence with `sort_properties=false`; explicit
sorting sorts all property kinds together. Variant writing avoids double
emission while retaining both a default and time samples. Crate writing uses
raw property children independently of authored metadata `propertyOrder`.
Canonical attribute-only prims with unrelated cold data no longer eagerly
allocate an order vector; capture begins only when needed for mixed/unsorted
names or an explicit crate child list.

New native writer coverage checks ordinary/variant raw order and clone behavior
through USDA, USDC, and USDC-to-USDA, including separate propertyOrder metadata
and a default plus samples. A stock contract also reads LightUSD-written USDC.
That check exposed and fixed duplicate placeholder/holder variant diagnostics
and noncanonical `/P/{v=x}` site spelling. Diagnostic sites now use `/P{v=x}`
(and corresponding descendant spellings), with one entry per contributing node.

Final native **99/99 PASS**, 84.31 s; stock oracle contracts **20/20 PASS**,
10.661 s. All 138 corpus cases remain: v1 **118 exact / 17 allowlisted /
0 unexpected**, strict v2 **91 exact / 44 differing**, no new differing cases
relative to the prior checkpoint. The zero ceiling still fails as required.
Logs: `/tmp/lean-property-roundtrip-{site-build,final-native,final-contract,
final-corpus}.log`. Final build is warning-free; diff whitespace check passes.
All processes are terminal. Shared dictionary comparator/stage-order work and
the broader plan remain incomplete; no overall checkbox is closed here.

## Shared compatibility comparator and stage ordering

`src/next/prim/name-order.hh` now supplies one allocation-free, arbitrary-length
numeric dictionary comparator to stage property enumeration and sorted USDA
writing. It follows stock OpenUSD byte ordering, including deferred ASCII case /
leading-zero differences, digits before underscores, non-ASCII unsigned bytes,
and first-mismatch digit-run boundary behavior. Raw PCP child/property sequences
remain separate. Stage property names now include authored relationships and
schema names, sort with the shared comparator, then move propertyOrder entries
to the front. This property order differs from grouped child-name restatement.
Relationship-map-only declarations also satisfy both HasProperty overloads and
HasAuthoredProperty.

The new native name-order test covers comparator laws over representative names,
400-digit numbers, stage partial propertyOrder, relationship existence and raw
order separation. The pinned stock differential checks **80,089 comparisons**
(including punctuation, Unicode and 500/600-digit runs) and **3 stage-order
scenarios**. Both native and stock ordering checks are wired into Lean CI.
Python syntax and workflow YAML checks pass.

Final native **100/100 PASS**, 86.43 s; PCP oracle contracts **20/20 PASS**,
11.236 s. All 138 corpus cases retained: v1 **118 exact / 17 allowlisted /
0 unexpected**, strict v2 **91 exact / 44 differing**, no new differing cases.
The strict zero ceiling remains unmet. Logs: `/tmp/lean-name-order-{final-build,
oracle,native,contract,corpus}.log`. All C++/corpus sessions are terminal.

Semantic review also corrected Path/Order.lean's claim of exact OpenUSD parity.
Its token-key model orders `a0_a` after `a00`; stock 26.11 orders them before.
The independent compatibility comparator reproduces the stock behavior. No Lean
definition/theorem was weakened or changed; the literal/compatibility model split
and general tokenizer/comparator laws remain unchecked. Finite native tests are
not evidence of a general Lean proof.

## Arc targets beneath relocation deletions

PathInRelocateSource now checks composed departure paths as well as normalized
raw source paths. This prevents arcs from reintroducing a child deleted beneath
an ancestral relocation target: `/P/Before -> /P/After`, then
`/P/After/Gone -> <>`. The normalized source alone is insufficient to reject an
arc to `/P/After/Gone` or its descendants. The same departure check also covers
renamed sources in that composed namespace.

The new production CLI contract compares internal references, inherits,
specializes, external references and external payloads with stock 26.11. Deleted
sites and descendants contribute no target specs/properties; the surviving
relocated sibling remains reachable. All **21 stock contracts PASS**, 9.766 s.
The focused RelocateToNone case passes without an allowlist and is pruned.

Full native **100/100 PASS**, 85.40 s, including serial/parallel PCP and the
pruned supplemental gate. Corpus retains **138 = 3 verified invalid + 135
structural cases**: v1 **119 exact / 16 allowlisted / 0 unexpected**; strict v2
**92 exact / 43 differing**, no newly differing cases. Initial full comparison
reported the expected RelocateToNone XPASS before pruning; the native corpus gate
then passed with the pruned ledger. Zero strict differences remains unmet.
Logs: `/tmp/lean-relocate-deletion-{build,contract,corpus,native}.log`.
All sessions are terminal. The broader relocation validator/semantic audit and
remaining composition/proof/validation requirements remain open.

## Ancestral arc cycles across files

ProcessArc now rejects a return to an ancestor of any earlier site in the same
layer stack on the active expansion branch, in addition to exact-site returns.
`/Parent/Child -> model:/Model -> /Parent` previously bypassed exact equality and
reintroduced the child recursively. The intermediate model node and its opinions
remain valid; only its closing arc is discarded. Unrelated targets in the same
external file remain reachable. The new stock contract checks this alongside a
direct same-file parent cycle and absence of recursively copied descendants.
This is an implementation repair, not a proof of general prim-index termination.

All **22 stock PCP contracts PASS**, 10.451 s. ErrorArcCycle passes the focused
legacy comparison without an allowlist and is pruned. Full native **100/100
PASS**, 104.51 s, no skipped/not-run tests, including serial/parallel PCP and the
pruned supplemental gate. All **138 = 3 verified invalid + 135 structural**
cases remain: v1 **120 exact / 15 allowlisted / 0 unexpected**; strict v2 **93
exact / 42 differing**, no newly differing cases. Initial full corpus reports
the expected stale XPASS; the subsequently pruned native corpus gate passes.
The strict zero ceiling remains unmet. Logs:
`/tmp/lean-ancestor-cycle-{build,contract,corpus,native}.log`.
All sessions are terminal; the full remaining plan is still active.

## Shared crate list-op framing and production vector coverage

`crate/listop-wire.hh` provides one public framing decoder: header/reserved-bit
validation, the six wire-vector ordering bits and u64 counts, and element limits
before consumer callbacks. PathListOp, Reference/PayloadListOp, Token/StringListOp
and Int64ListOp production readers now use it. Type-specific element bytes,
index validity, allocation budgets and existing marker/explicit-clear behavior
remain with each consumer. PathVector retains its single-vector framing.
This refactor intentionally does not change non-canonical mode/setter semantics.

The eight committed LEAN_CRATE_LISTOP wire vectors now have a real C++ consumer.
It checks all six raw vectors, every truncated prefix, reserved bits and count
limits before callbacks. Each decoded vector is also authored as an actual Int64
extension field, serialized, compared byte-for-byte at the real crate payload,
and re-read through the production Int64 field decoder; header and all retained
vectors match the independent Lean expectations, including all-ones u64 words.
The vector binary reports **23,716 checks / 0 failures**, and its existing CI gate
now includes this table. Reflection matrix updated; stale corpus counts and a
premature relocation-validator registration claim were corrected.

Final native **100/100 PASS**, 85.18 s, no skipped/not-run tests. Stock PCP
contracts **22/22 PASS**, 11.829 s. All 138 corpus cases remain: v1 **120 exact /
15 allowlisted / 0 unexpected**; strict v2 **93 exact / 42 differing**, no newly
differing cases. The strict zero ceiling remains unmet. Public header compiles
standalone under C++17 with Wall/Wextra/Werror. Logs:
`/tmp/lean-listop-wire-{build,final-build,vectors,native,contract,corpus}.log`.
All sessions are terminal.

LEAN-414 remains a distinct semantic obligation: the raw header decoder and
canonical generated vectors do not establish OpenUSD setter-mode behavior for
headers such as 0x02 or 0x22. Int64 is_explicit and marker readers still preserve
the earlier interpretation. Keep this finding open until production semantic
normalization and stock non-canonical wire tests exist.

## LEAN-414 production compatibility semantics

Production readers now normalize mode using the separate OpenUSD setter model:
0x02 enters explicit mode; any composable vector switches back to non-explicit
mode and discards explicit items, including when the composable vector is empty.
Raw framing remains separate and validates every discarded vector. Header 0x00
also now survives the marker bridge as an authored composable no-op instead of
being mistaken for an explicit clear. Int64, token, string, path, reference and
payload readers use the same semantic helpers; relationship targets and
attribute connections retain the distinction too.

Added **256 LEAN_CRATE_LISTOP_MODE rows**, generated from `pxrRead` for all 128
legal headers with populated and empty vectors. The C++ consumer checks helper
semantics and actual Int64 writer payloads/reader vectors. Total native Lean
vector checks are **38,564 / 0 failures**. The separate pinned-stock test covers
**2,048 real crate cases** across six wire types and eight consumer contexts,
comparing mode, all six lists, effective Int64 results, and authored field
presence after rewriting. Coverage is checked by exact filename sets. Discarded
explicit vectors are also tested with bad indices and excessive counts.

Preserved the existing parsing profiles: malformed optional fields warn and are
ignored in compatibility mode, and reject strict AOUSD loads; memory/count caps
remain hard failures. The malformed-USDC suite verifies this policy, and the new
corruption cases verify it for every affected consumer. No global diagnostic
policy tightening remains in the final implementation.

LEAN-414 is now **verified (source + stock 26.11), implementation fixed, not
filed** in ISSUES.md. Seven original candidate findings still require their
independent resolutions. Raw `decode` and compatibility `pxrRead` remain distinct;
no original theorem/domain was weakened. CI requires the new stock comparison.

Final native **100/100 PASS**, 84.93 s, no skips/not-run tests; stock PCP contracts
**22/22 PASS**, 11.672 s. Full 138 cases retained: v1 **120 exact / 15 allowlisted
/ 0 unexpected**, strict v2 **93 exact / 42 differing**, no new differences. The
strict zero ceiling remains unmet. Generator drift, runtime, axiom audits and
reflection gates pass in the native suite; registry remains **73 tags**. Header
standalone C++17 checks, Python syntax, CI YAML and diff whitespace checks pass.
Logs: `/tmp/lean-listop-mode-{validation-build,generate,vectors,final-oracle,
malformed,final-native,final-contract,final-corpus}.log`. All sessions terminal.
Unknown-metadata folding, other validators/relationships, the remaining formal
proof/audit tasks, 42 strict differences and broad final gates remain open.


## Local unknown-metadata folding and crate source typing

Shared the existing layer-local assignment rules with prim, variant and property
metadata: repeated qualified opinions replace earlier values; a bare assignment
removes prior qualified opinions and suppresses later qualified edits. No generic
registered cross-layer composition semantics were added. Native conformance tests
cover eight patterns in all four scopes through text and crate round trips.

The stock 26.11 comparison retains all 36 fixtures: 32 accepted, four explicitly
classified qualified-empty-list text rejections, and 64 accepted text/native-crate
comparisons. CI now requires this check. Private raw metadata crate storage is
not claimed to interoperate with stock. Property raw-source emission also no
longer adds an extra quoting layer. Real typed crate strings remain distinct from
UnregisteredValue; a focused round-trip test verifies array-like string contents
stay typed and quoted. That final test-only incremental build and conformance run
both pass.

Native suite: **100/100 PASS**, 90.67 s. Stock PCP contracts: **22/22 PASS**,
12.935 s. Full corpus: **138 retained**, v1 **120 exact / 15 allowed / 0 unexpected**,
strict **93 exact / 42 different**. Exact strict differing-case sets are unchanged;
the zero strict ceiling still fails. Logs: `/tmp/lean-raw-metadata-{native,contract,
corpus,oracle,typed-build,typed}.log`. The full suite preceded the final additional
typed-string test; the final conformance binary was then rebuilt and passed.

Issue draft 16 was polished to remove an unsupported broad LightUSD relocation
validation parity claim; the verified stock example remains. No issue was filed.
The remaining formal audit/proofs, validator/relationship work, strict composition
differences and broad final gates are still open. No commits or pushes performed.


## Relationship default authored state (partial)

Added PropMeta::kRelDefault so authored `rel r.default = <>` differs from absence.
The parser sets the bit, weak metadata merging fills only an unauthored default,
and the USDA writer preserves empty and relative defaults using statement syntax
without emitting a metadata block solely for the default. Native conformance
covers absent/empty/relative stronger opinions over a weaker absolute default and
text fixpoints. Focused conformance passes after the final rebuild.

Pinned official stock 26.11 independently preserves empty, relative and absolute
SdfPath defaults in USDA, but rejects USDC export for all three with unsupported
SdfPath. Evidence: `/tmp/lean-rel-default-stock.log`. This is not a completed crate
round-trip solution: the overall relationship-default item stays unchecked. Do not
claim standard USDC compatibility by silently substituting a string field.
Build/test logs: `/tmp/lean-rel-default-{build,final-build,conformance}.log`.


LEAN-801 candidate audit: re-read verified spec L10123/L10383 and clean
v26.11.1 textFileFormatParser.h ListValue/ReferenceList definitions. Isolated
stock 26.11 provenance checked; apiSchemas empty qualified list rejects,
nonempty list and None accept; bare references=[] accepts while qualified
references=[]/None reject semantically. Six assertions pass in
`/tmp/lean-801-stock.log`; clean tagged parser snapshot is
`/tmp/lean-801-stock-parser.h`. Registry downgraded to verified syntax note,
not an established defect and not filed. Six original candidates remain after
414 and 801 resolutions. General grammar round-trip proof remains open.


Final relationship-default checkpoint: full rebuilt standalone Debug native suite
**100/100 PASS**, 87.09 s; pinned stock PCP contracts **22/22 PASS**, 10.049 s.
After the LEAN-801 documentation correction, `lake build` passes (3175 jobs).
Reflection resolves 7/7 and whitespace checks pass. Logs:
`/tmp/lean-rel-default-{all-build,native,contract,proof,reflection}.log`.
All launched build/test sessions are terminal. No new corpus run was needed for
the local authored-state-only change; the immediately preceding full corpus
remains 138 retained with the same 42 strict differences. Overall goal remains
active and full closure is unproven.


## Implied specializes selection strength

Fixed ancestor-stack implied specializes selection merging: existing selections
from the specializing prim remain stronger; implied inherits retain their
separate promotion behavior. The BasicSpecializesAndVariants_root corpus case
now matches stock ordered v2 exactly and was pruned from the engine allowlist.
The full 138-case comparison before pruning improved to 121 exact / 14 allowed /
0 unexpected, and strict 94 exact / 41 differing. Comparing exact differing-case
sets against the preceding baseline finds only this closure, no new differences.
The zero strict ceiling remains unmet. A post-prune full run is in progress.

The PCP contract adds four complete pinned-stock comparisons: direct selections
brass/base, explicitly empty selection, and absent selection across a reference
with an ancestor class override. 23/23 contracts pass, 10.735 s, including all four
controls. New fixture syntax was corrected to include stock-required statement
newlines before closing variant braces; no comparison was relaxed. Logs:
`/tmp/lean-specialize-selection-{build,case,contract,corpus,all-build}.log`.

LEAN-802 audit independently re-read normative RelationshipSpec L10779-10787,
the explicit optional legacy boundary L11376-11387, and the only definition at
L11489-11490 in the immutable spec. Clean v26.11.1 parser defines the default
branch directly (KeywordDefault, Assignment, PathRef), in the tagged snapshot
`/tmp/lean-801-stock-parser.h`. The existing kernel theorem identifies exactly
one undefined normative symbol. Registry now records a confirmed grammar defect,
not filed; five of the eight original candidates remain unresolved. No Lean
definition or theorem was changed for this status correction.


Final implied-specializes checkpoint: all rebuilt Debug native tests **100/100
PASS**, 83.87 s, including Lean build/runtime/drift/axioms/reflection and the
expanded native PCP contract. Stock contracts **23/23 PASS**, 10.735 s.
Post-prune full corpus retains all **138 cases**: **121 exact / 14 allowed /
0 unexpected**, no XPASS; strict **94 exact / 41 different**, with exactly one
closure and no new differing cases. Strict zero ceiling still fails as expected
and is not waived. Reflection 7/7, Python syntax and diff checks pass. Logs:
`/tmp/lean-specialize-selection-{native,final-corpus,contract,reflection}.log`.
All sessions terminal. Full objective remains active with substantial formal,
composition, validator and broader validation work outstanding; no commits,
pushes or external filings performed.


## Nested variant diagnostic site identity

Actual selected sources now represent applied-variant records only when the
complete selection chains match. Prefix/substring tests confused enclosing and
nested options, dropping the former and duplicating the latter. The unchanged
BasicNestedVariants_root asset now matches the stock ordered stack exactly.
Four regression combinations vary outer/inner inline properties while retaining
child content and a repeated set name at a deeper level; all complete v2 outputs
match pinned stock. PCP contracts **24/24 PASS**, 12.463 s.

Full 138-case corpus: legacy **121 exact / 14 allowed / 0 unexpected**, strict
**95 exact / 40 different**. Exact differing-case comparison shows only
BasicNestedVariants_root closed and no new cases; zero strict ceiling remains
unmet. No allowlist relaxation or case removal. Logs:
`/tmp/lean-nested-site-{build,case,contract,corpus,all-build}.log`.
Full rebuilt native suite is running in `/tmp/lean-nested-site-native.log`.

LEAN-804 was audited against the immutable keyword prose/table and clean tagged
OpenUSD parser. The facts proved by the grammar checker hold, but do not imply
that every literal must be reserved or that reserving varying is a defect;
legacy rules use varying. Tagged parser likewise omits autoEase from Keywords,
while defining it separately, and uses math rules for inf/nan. Registry now
classifies it as a verified syntax note, not filed.

LEAN-746 was independently checked against spec L7878-7903, clean v26.11.1
`pxr/base/ts/eval.cpp` (_GetExtrapolationSlope: one knot => 0.0), and the isolated
stock 26.11 runtime with wheel provenance verified. Four interpolation modes,
nonzero pre/post tangents, five value queries and four derivative queries each
all give value 7 and derivative 0. Evidence:
`/tmp/lean-746-stock.log`, `/tmp/lean-746-stock-eval.cpp`. Registry now confirms
the single-knot omission. No theorem/domain changed. Three original candidates
remain (501, 311, 767). The broader proofs and semantic audit remain open.


Final nested-site checkpoint: rebuilt full Debug native suite **100/100 PASS**,
84.88 s (including Lean build/runtime/drift/axioms and expanded PCP contracts).
Pinned stock contracts **24/24 PASS**, 12.463 s; full corpus remains **138 cases**,
legacy **121 exact / 14 allowed / 0 unexpected**, strict **95 exact / 40 different**.
All 73 unique registry findings retained; 804 is a verified note and 746 confirmed.
Reflection 7/7, Python syntax, diff whitespace pass. Logs:
`/tmp/lean-nested-site-{native,contract,corpus}.log`. All sessions terminal.
No commits, pushes, case removals or issue filings. Goal remains active; completion
of the complete plan is not established.


## LEAN-767 clip activation ordering and duplicate validation

Audited immutable spec L6684-6687/L6941-6958 against clean v26.11.1
`pxr/usd/usd/clipSet.cpp`: validation rejects any duplicate active time (even an
identical index), and startTimeToClip orders unique times chronologically.
Stock 26.11 provenance checked. Five actual two-asset clip fixtures query five
times each: sorted and unsorted controls give identical values, including the
expected cross-boundary interpolation; three duplicate cases give no clip values.
Evidence: `/tmp/lean-767-stock.log`, `/tmp/lean-767-stock-clipSet.cpp`.

Native ParseValueClipSets now rejects equal activation times after sorting,
including nonadjacent authored duplicates. Native conformance covers the same
five metadata patterns and unique interval boundaries. Focused conformance passes.
This rule does not reject the distinct two-entry clip-times jump representation.

Lean's literal activeIndex remains unchanged. Added separate sortedActive,
prepareActive and pxrActiveIndex compatibility definitions, with general kernel
proofs of sorted output, uniqueness, permutation preservation, and acceptance of
all unique inputs. Four examples cover unordered intervals and duplicate
rejection. Asset-index validation and filesystem behavior are explicitly outside
this helper's model; their production checks remain separate. No existing
formula, theorem or input domain was weakened. Direct Lean validation passes.

Registry LEAN-767 now confirmed and implementation fixed, not filed. Two original
candidate findings remain (501, 311). The full module audit, broader proofs and
composition work remain open. Stock sampled-value regression reports **304
queries, 0 unexpected mismatches, 0 classified timing differences**; docs corrected
to supersede the old six-difference note. Logs:
`/tmp/lean-clip-active-{build,test-build,conformance,proof,all-build,sampled}.log`.
Full native suite is running in `/tmp/lean-clip-active-native.log`.


Final clip-active checkpoint: full rebuilt Debug native suite **100/100 PASS**,
89.33 s, including new compiled Lean proofs, runtime/drift/axiom audit and native
clip rejection cases. Isolated stock sampled values **304/304 match**, no
unexpected or classified timing differences. Reflection **7/7**, 73 unique
registry findings retained, whitespace checks pass. Logs:
`/tmp/lean-clip-active-{native,sampled,reflection,proof}.log`.
All sessions terminal. Composition was not modified in this checkpoint; the last
full strict corpus measurement remains 95 exact / 40 different, all 138 retained.
Only two original candidate findings remain (501, 311), but the full audit,
proof/implementation gaps and final gates remain incomplete. Overall goal stays
active. No commits, pushes or issue filings.


## Original candidate audit completed (501 and 311)

LEAN-501 is now a verified modeling note: relocation metadata creates prim-index
relocation nodes; absence of a list-op field does not contradict arc-type strength
ordering. Clean v26.11.1 primIndex.cpp creates direct nodes with parent=origin
and sibling index 0 because each destination has one source. strengthOrdering.cpp
compares arc type first, then origin depth/strength. Strength.lean now states
explicitly that arbitrary ArcInfo values exceed valid relocation graph nodes;
no definition/proof was changed or narrowed. Richer prim-index invariants remain
open. Tagged source snapshots: `/tmp/lean-501-{primIndex,strengthOrdering}.cpp`.

LEAN-311 is confirmed as literal-pseudocode defects: inclusions are appended once
before recursively composing their schema lists, which appends again; the later
example omits the inherited BarBaz:otherInstance. The cycle theorem concerns
literal recursion without an implicit cache, not OpenUSD divergence. Clean tagged
schemaRegistry.cpp tracks Building/Complete and skips cyclic inclusions;
primDefinition.cpp appends only new schema family/instance/version entries.
Stock 26.11 provenance verified; seven built-in definition controls have unique
expanded lists, including five lights with LightAPI and both collection instances.
These controls do not recreate the hypothetical FooBar examples. Evidence:
`/tmp/lean-311-{schemaRegistry,primDefinition}.cpp`, `/tmp/lean-311-stock.log`.

All eight original candidates are resolved: 414/767 fixed; 501/801/804 notes;
311/802/746 confirmed. No findings were dropped, no external reports filed.
Registry-wide line/coverage/module audit is still open and is not implied by
this narrower closure. Updated ledger and module caveats. `lake build` passes
3175 jobs in `/tmp/lean-candidate-final-build.log`; all 12 Lean-labeled gates
are currently running in `/tmp/lean-candidate-final-gates.log`.


Final candidate-audit checkpoint: all **12/12 Lean-labeled gates PASS**, 65.58 s,
including compiled theorem axiom scan, imported-module negative tests, proof
build/runtime, all vector drift/consumers, reflection and PCP contract. Logs:
`/tmp/lean-candidate-final-{build,gates}.log`. All sessions terminal. The registry
retains 73 unique findings; none of the eight original rows remains candidate.
No C++ behavior changed in this checkpoint; the latest full native result remains
100/100 and sampled-value result 304/304. Broader semantic audit, general proofs,
40 strict composition differences, relationship crate preservation and other
unchecked plan requirements remain incomplete. Goal remains active; no commits,
pushes or external issue filings.


## General tokenizer injectivity and comparator equality

Closed the Path/Order element-name proof gap without changing tokenizeAux,
digitStep, tokenization, key definitions or comparator behavior. Added a decimal
speller using arbitrary-precision Nat.digits, retaining the leading-zero count.
The digit-step spelling lemma handles all-zero and significant-digit cases;
structural induction proves detokenize(tokenizeAux cs pending) equals the pending
run's spelling followed by cs for EVERY character list and pending accumulator.
Thus detokenize(tokenize cs)=cs and tokenize is injective, with no length, ASCII-
name, bounded-value or valid-identifier restriction. Non-digit Unicode characters
are retained exactly; only the run branch requires the existing ASCII isDigit
predicate. No theorem/input domain was weakened.

Primary keys have exactly two words per token. General proofs establish joint
primary/secondary key injectivity for ALL Token values and Token lists, including
values outside the tokenizer's image. Combining these with the tokenizer inverse
proves elemCompareList equality iff character-list equality and elemCompare
equality iff String equality. Added actual-equality trichotomy and non-strict
antisymmetry; existing strict transitivity, reflexivity and swap laws remain.

The stronger mathematical result does NOT establish exact OpenUSD byte ordering
or close the literal/compatibility model split. The documented a0_a/a00 boundary
remains, and the native stock-tested comparator is unchanged. Full path/sibling
validity and the broader formal module review remain separate obligations.

Direct Lean validation and lake build (3175 jobs) pass. Logs:
`/tmp/lean-order-{keys-proof,tokenizer-proof,tokenizer-build}.log`. All 12 Lean-
labeled gates are running in `/tmp/lean-order-tokenizer-gates.log`; reflection
check resolves 7/7. Docs/ledger now mark the specific tokenizer/name comparator
proof item complete while preserving the remaining general proof requirements.


Final tokenizer checkpoint: **12/12 Lean-labeled gates PASS**, 67.76 s, including
compiled project axiom scan, imported-module negative tests, runtime, vector
consumers/drift, reflection and PCP contracts. Axiom audit now covers **2525
theorems (331 private), 33 modules**, with only propext/Classical.choice/Quot.sound.
README's measured count updated. No generated vector behavior changed. Logs:
`/tmp/lean-order-tokenizer-{build,gates,proof,reflection}.log`. All sessions
terminal; whitespace checks pass. No C++ behavior changed, no commits, pushes or
issue filings. The full objective remains active: general PATHS/USDA/NFC/spline
proofs, full semantic audit/model split, richer prim-index invariants, 40 strict
composition differences, validator and relationship crate work and broad final
gates still require completion.


## General decoded-row PATHS correctness

Added a general prefix/suffix framed forest round-trip theorem with arbitrary
accumulated output, parent path, signed element tokens, and path indices. Its
induction handles leaf, sibling-only (0), child-only (-1), and child+sibling
(positive subtree-length jump) cases. The forest is decoded completely without
consuming surrounding rows when fuel is at least its encoded row count.

Derived decode_encode_of_le for every Node and sufficient fuel, and decode_encode
at exactly encoded row count. Root token remains ignored exactly as in the
original decoder and expected paths function. No encoder/decoder/expected-output
definition, accepted domain or existing theorem was changed. No arbitrary depth,
width, token-value or index bound was introduced.

General index-projection theorems show decoded indices equal the encoded row
sequence, including arbitrary sparse indices. This is event-list preservation,
not binary table-bound or uniqueness validation; those remain separate native
validation obligations. Also proved encoded chain length=n+1, failure for every
fuel≤n (with arbitrary framing/parent/accumulator), and minimal successful fuel
n+1. Thus the row-count sufficient bound is tight on chains of every length.

The previously open decoded-row tree/fuel/sparse-index/jump-form item is now
checked in the ledger. General malformed-table validation, byte/integer bounds,
PATHS table total count, and the broader implementation audit are not implied by
this result. Direct kernel validation and full lake build pass (3175 jobs).
Logs: `/tmp/lean-paths-general{,-build}.log`. All 12 Lean-labeled gates are running
in `/tmp/lean-paths-general-gates.log`; reflection resolves 7/7. No C++ behavior
or generated vector expectation changed. Full objective stays active.


Final PATHS checkpoint: **12/12 Lean-labeled gates PASS**, 65.86 s, including
proof/runtime, all committed vector consumers/drift, reflection/PCP contracts,
full compiled axiom scan and imported-module negative tests. Axiom scan now covers
**2579 theorems (344 private), 33 modules** with only the three allowed standard
axioms. README count updated. Reflection 7/7 and whitespace checks pass. Logs:
`/tmp/lean-paths-general-{build,gates,reflection}.log`; exploratory direct proof
log `/tmp/lean-paths-general.log` is also successful and contains no admitted proof.
All sessions terminal. No runtime definitions or C++ behavior changed, no commits,
pushes or reports filed. General USDA/NFC/spline proofs, full semantic audit/model
split, richer prim-index model, 40 strict composition differences and remaining
native validators/relationship crate preservation/final gates remain open.


## USDA quoted-string foundation and unrepresentable crate values

Added Usda/Quoted.lean and connected it to the existing supported-AST q/str
functions. General kernel proofs recover arbitrary character lists and Strings,
including all controls/NUL/Unicode, with arbitrary trailing input and an explicit
fuel bound. Canonical printing emits controls as three-digit octal and backslash
as \134; quote uses \". Named escapes and OpenUSD's backslash source escape are
also accepted. Hex and short-octal source forms remain outside this codec.
The whole supported-AST theorem is STILL OPEN; no AST domain or old proof was
weakened, and existing examples continue to pass. Numeric/identifier/structural
well-formedness and recursive AST composition remain to be proved.

Added a 16th committed-table artifact, usda-string-vectors.inc, computed from the
Lean quoteString function: 40 cases (all 32 controls plus quotes/backslash/DEL/
Unicode/mixed/empty/NUL followed by a digit). Native consumers check exact values
with explicit string lengths through source, USDA and representable USDC. This
exposed a Gen.cstr bug: decimal text after backslash became a different C++ octal
value and could consume following digits. Gen.cstr now emits exactly three octal
digits; the independent stock script also checks all expected values against a
separate Python manifest so shared source/expectation bugs cannot cancel.

Both official stock 26.11 and prior native crate writing silently truncate values
at embedded NUL because TOKENS uses NUL terminators. All 40 source cases remain.
Native writer now records a clear error when interning an unrepresentable token,
using worker-local error propagation and preserving valid provisional indices
until abort. Existing token hits avoid repeated scans. Serial and parallel field
writers are tested with the bad value after 8192 valid prims. Stock's two lossy
exports are explicitly classified; native rejects both instead of reporting
success. This does not invent a nonstandard crate representation.

Pinned stock string gate (now mandatory in Lean CI): **40 retained, 118 exact
source/native-text/native-crate value checks, 38 stock crate roundtrips, 2 classified
stock NUL truncations**, native rejects both. New script:
tests/next/test-usda-strings.py. Native vector total **38686 checks / 0 failures**.
Final full Debug native **100/100 PASS**, 89.31 s; stock PCP contracts **24/24 PASS**,
15.350 s. Full corpus retains **138**: v1 **121 exact / 14 allowed / 0 unexpected**,
strict **95 exact / 40 different**, exact differing-case set unchanged; strict zero
ceiling still fails and is not waived. Axiom audit: **2634 theorems (363 private),
34 modules**, only standard allowed axioms. Sixteen table drift gates, reflection
7/7, Python syntax, YAML parse and whitespace checks pass. Logs:
`/tmp/lean-usda-escaping-{build,generate,final-build,final-native,final-stock,
contract,corpus,reflection}.log`. All sessions terminal. No commits/pushes/filings.
Overall objective remains active; complete AST/NFC/spline/prim-index guarantees,
semantic audit/model split, remaining composition/validator/relationship work and
broader final gates are not closed by this checkpoint.


## USDA lexical and list composition proof foundation

Added Usda/GrammarProofs.lean, imported by the umbrella build. No parser/printer
runtime definition was changed. General proofs now establish take/drop prefix
behavior, whitespace indentation, exact identifier and numeric-lexeme scanning
with explicit token-boundary conditions, and asset/path delimiter inverses with
arbitrary trailing input. Specifier parsing is generalized to arbitrary input
after its separating space.

The named IdentLexeme predicate describes THIS subset's scanner, not full XID;
NumLexeme describes scanner characters, not normative Number PEG acceptance or
numeric conversion. Delimiter safety is lexical, not semantic USD path/asset
validation. These are explicit preconditions for future whole-AST well-formedness,
not silently assumed compatibility claims.

A general listUntil theorem recovers unbounded lists and prior accumulated items
with fuel>=item count+1, arbitrary closing indentation and trailing input. Its
item-domain/inverse and non-closing-start conditions are explicit. Bridge lemmas
connect the actual bracket String printer to this input shape and prove that the
printer's character-count fuel is sufficient. The pathRef_bracket theorem
DISCHARGES the item assumptions for the actual path-reference list printer used
by inherits/specializes, recovering any delimiter-safe list exactly. No desired
whole-list parser result is assumed to prove that instance.

The whole supported-AST round-trip requirement stays UNCHECKED. Remaining work
includes recursive Prim/dictionary composition, offset/reference/sample cases,
well-formed numeric/identifier fields and AST-wide fuel bounds. No theorem or
accepted domain was weakened and no examples were substituted for those remaining
requirements. New proofs build successfully (3177 jobs), with no admitted proof,
custom axiom or native_decide. Reflection resolves 7/7 and whitespace passes.
Logs: `/tmp/lean-usda-lexical{,-build,-reflection}.log`. All 12 Lean-labeled gates
are running in `/tmp/lean-usda-lexical-gates.log`. C++ behavior and all 16 vector
expectations remain unchanged. Goal remains active.


Final lexical/list checkpoint: **12/12 Lean-labeled gates PASS**, 68.77 s, including
full build/runtime, all 16 vector tables/consumers/drift, reflection/PCP contracts,
compiled axiom audit and imported-module negative tests. Axiom scan covers **2687
theorems (371 private), 35 modules**, with only standard allowed dependencies.
README count updated. Reflection 7/7; whitespace checks pass. Logs:
`/tmp/lean-usda-lexical-{build,gates,reflection}.log`. All sessions terminal.
No C++ or executable parser/printer definition changed in this checkpoint; no
commits, pushes or reports filed. The complete supported-AST theorem remains
unchecked, as do the other full-goal requirements and 40 strict composition
differences. Goal remains active.


## USDA offsets, references and sublayers

Added Usda/OffsetProofs.lean and imported it into the umbrella build. No executable
parser/printer definition changed. General proofs cover absent, offset-only,
scale-only and both-field Offset.print forms; the existing parser's character-
count fuel is proved sufficient in each case. They preserve exact lexemes and
arbitrary following input, with no lexeme-length bound.

Derived exact SubLayer.print and Reference.print inverses. References cover
asset-only, path-only and combined forms; the no-asset/no-path state is explicitly
excluded because the existing parser rejects it. Delimiter safety and lexical
numeric conditions are explicit admissibility predicates. They do not assert
finite numeric values, nonzero scale, URI or USD object-path semantics.

Whitespace-idempotence and prefix lemmas establish reference/sublayer behavior
under arbitrary whitespace prefixes. Using the previous generic bracket/list
proof, both reference_bracket and subLayer_bracket recover lists of any length
with arbitrary indentation and trailing input. Their item-inverse/start premises
are discharged for the actual printers, not assumed as whole-list results.

The full supported-AST theorem remains unchecked: recursive prim/dictionary,
sample-value, metadata assembly and AST-wide fuel work still remain. This closes
component obligations without substituting a smaller final objective or changing
any old theorem/domain. Direct validation and lake build pass (3178 jobs). Logs:
`/tmp/lean-usda-offsets{,-build}.log`. All 12 Lean-labeled gates are running in
`/tmp/lean-usda-offsets-gates.log`; reflection resolves 7/7 and whitespace passes.
Native behavior and all 16 generated vector expectations remain unchanged.


Final offset/reference checkpoint: **12/12 Lean-labeled gates PASS**, 67.04 s,
including build/runtime, all 16 vectors/consumers/drift, reflection/PCP contract,
compiled axiom scan and imported-module negative tests. Axiom scan now covers
**2728 theorems (375 private), 36 modules**, with only standard allowed axioms.
Scalar item inverse statements include the canonical comma boundary and preserve
arbitrary suffix input after it; list inverses preserve arbitrary input after
closing brackets. README count and scope clarified. Reflection 7/7 and whitespace
checks pass. Logs: `/tmp/lean-usda-offsets-{build,gates,reflection}.log`.
All sessions terminal. No executable parser/printer or C++ behavior changed, no
commits/pushes/filings. Full supported-AST proof and other unchecked requirements,
including 40 strict composition differences, remain open; goal stays active.


## USDA sample maps and attribute-only bodies

Added Usda/SampleProofs.lean and imported it into the umbrella build. Direct
induction on the existing samples parser proves exact recovery of arbitrary-
length sample maps, authored pair order, prior accumulated entries, indentation
and arbitrary trailing input, with fuel>=sample count+1. A bridge to the actual
String.join row printer proves its character-count fuel sufficient. No sample
count or lexeme length bound was introduced.

General attrRest inverses now cover both default numeric and .timeSamples
statements. primItems_printAttr advances the ACTUAL primItems parser across
either printed statement with arbitrary leading whitespace and continuation.
primItems_attrs proves complete recovery of unbounded attribute-only bodies,
including closing-brace indentation and arbitrary trailing input, with sufficient
item-count fuel. No whole-body parser result is assumed to prove this case.

The explicit SampleWellFormed/AttrWellFormed predicates are lexical subset
admissibility. They do not assert full XID/Number PEG acceptance, finite values,
sorted/unique timestamps or interpolation/value-resolution semantics. Nested
prims, metadata/dictionaries and whole-AST assembly/fuel remain open. The top
whole-AST checkbox remains unchecked. No executable parser/printer definition,
old theorem or accepted domain was changed or weakened.

Direct validation and lake build pass (3179 jobs), with no admitted proof,
custom axiom or native_decide. Reflection 7/7 and whitespace checks pass. Logs:
`/tmp/lean-usda-samples{,-build,-reflection}.log`. All 12 Lean-labeled gates are
running in `/tmp/lean-usda-samples-gates.log`. All 16 vector expectations and C++
behavior remain unchanged. Overall objective remains active.


Final sample/attribute checkpoint: 12/12 Lean-labeled gates PASS, 66.72 s.
Compiled axiom audit: 2774 theorems (392 private), 37 modules, only the three
allowed standard axioms. All 16 vector expectations/consumers/drift, runtime,
reflection/PCP and negative trust tests pass. All sessions terminal. Whole-AST
proof remains open. No executable model or C++ behavior changed; no commits,
pushes or reports filed. Logs: /tmp/lean-usda-samples-{build,gates,reflection}.log.

Metadata assembly follow-up: `UsdSpec/Usda/MetadataProofs.lean` adds a general
whitespace-prefixed bracket-list inverse with arbitrary trailing input and
unbounded item count. It uses the actual input-length fuel, including padding,
and preserves the existing per-item inverse and lexical-start hypotheses.
Concrete path-list and reference-list specializations retain delimiter-safety
and Reference.WellFormed conditions. This closes a printer/parser boundary
needed after metadata `=`; it does not yet prove primMeta/primMetas, customData
or whole-Layer AST recovery. No executable model or C++ behavior changes.

Final metadata-list checkpoint: lake build passes (3180 jobs). All 12 Lean
validation gates PASS in 66.07 s, including all 16 vector tables/consumers/drift,
reflection/PCP, negative trust tests and compiled axiom audit. Audit: 2783
project theorems (396 private), 38 modules, only propext/Classical.choice/
Quot.sound. Reflection references 7/7; git diff --check passes. Logs:
/tmp/lean-usda-metadata-{build,reflection,final-gates}.log. All sessions terminal.
The new MetadataProofs module proves whitespace-prefixed actual bracket-list
inverses and concrete path/reference specializations with unchanged lexical
hypotheses. No executable parser/printer or C++ changes in this checkpoint.
Whole AST and the broader follow-up plan remain open. Next: prove actual
primMeta arc cases, primMetas accumulation, dictionaries and nested prim assembly.
AOUSD report 16/review rechecked: stock evidence is explicitly scoped; complete
LightUSD relocate validation remains open. No report filed, commit or push.

Arc metadata and flat dictionary assembly follow-up:
- MetadataProofs now proves actual primMeta recovery for references, inherits and
  specializes for every Qual, preserving lexical delimiter/offset hypotheses.
  Direct primMetas induction covers arbitrary length/order, accumulated entries,
  leading/closing whitespace and trailing input. The String.join printer bridge
  proves actual input-character fuel sufficient. ArcWellFormed is lexical only;
  it explicitly excludes customData and does not certify composition validity.
- DictionaryProofs proves numeric scanner admissibility and exact int recovery
  for every printed Int (including negative and arbitrary magnitude), plus key
  fallback and quoted-string recovery. Actual dictItems steps and whole flat
  dictionary bodies preserve exact keys/values and authored order, with general
  item-count fuel. dict_primitives and primMeta_customData_primitives_print cover
  actual braces and metadata dispatch, including input-length fuel.
- PrimitiveEntryWellFormed explicitly excludes nested dictionaries and uses the
  existing IdentLexeme subset. Nested dictionaries, mixed metadata assembly,
  nested prims and whole-Layer AST remain open; no top-level checkbox is closed.
No executable parser, printer, accepted domain or C++ behavior changed.

Final arc/flat-dictionary checkpoint: lake build PASS (3181 jobs), 12/12 Lean
validation gates PASS in 67.82 s. Compiled axiom audit: 2913 theorems (450
private), 39 modules, only propext/Classical.choice/Quot.sound. All 16 generated
vector tables/consumers/drift, runtime, reflection/PCP and negative trust tests
pass. Reflection 7/7 and git diff --check pass. No executable parser/printer or
C++ changes; no commits, pushes or issue reports filed. All sessions terminal.
Logs: /tmp/lean-usda-arc-dict-{build,gates,reflection}.log.

MetadataProofs now includes actual three-arc primMeta inverses, primMeta_padding,
ArcWellFormed (lexical only; customData excluded), metaBody and direct primMetas
induction for unbounded arc blocks, closing padding, arbitrary acc/tail and
String.join/input-length-fuel bridge. DictionaryProofs is imported by UsdSpec:
unbounded Int codec + lexical key + arbitrary quoted-string inverses, actual
primitive dictItems steps, arbitrary-length flat bodies, dict_primitives,
print-length bound and actual primMeta customData inverse for flat dictionaries.
PrimitiveEntryWellFormed deliberately excludes nested dictionaries; this is an
intermediate theorem, not closure of the supported-AST requirement.

Next concrete work: recursive dictionary assembly (then all metadata, nested
prims, whole Layer). /tmp/lean-usda-nested-dict.lean has only two compiled scratch
definitions (not repo source): dictCost counts nested container/entry overhead;
EntriesWellFormed recursively requires IdentLexeme keys at every depth. The
required general proof still needs dictionary-typed prefix/step and recursive
cost induction, plus printed character-count fuel dominance. Do not assume the
scratch definitions prove recovery or weaken whole-AST scope. Full plan remains
active with existing unchecked items; native behavior/corpus last validated
results remain as recorded in preceding checkpoints.

Recursive metadata follow-up: RecursiveMetadataProofs.lean adds direct recovery
of actual dictItems/dict for arbitrary-depth, arbitrary-length dictionaries.
EntriesWellFormed retains IdentLexeme key admissibility recursively, with no
integer-magnitude, string-length or depth bound. dictCost is a conservative
container/entry fuel bound; dictCost_print_bound and dict_print_length prove
printed character fuel sufficient. primMeta_customData_nested_print dispatches
through the actual metadata parser. PrimMeta.WellFormed, primMeta_print,
primMetas_print and primMetas_print_text now cover all four supported metadata
constructors, including mixed qualifiers and nested dictionaries, arbitrary
accumulated entries/order, whitespace and trailing input.
These are subset lexical inverses, not semantic composition or full-PEG claims.
No executable parser/printer definition or accepted domain was changed. Nested
prim and whole-Layer assembly remain open; the whole-AST checkbox stays unchecked.

Final recursive-metadata checkpoint: lake build PASS (3182 jobs), all 12 Lean
validation gates PASS in 66.89 s. Compiled axiom audit: 2978 theorems (464
private), 40 modules; only propext/Classical.choice/Quot.sound. All 16 vector
expectations/consumers/drift, reflection/PCP and negative trust tests pass;
reflection references 7/7; git diff --check passes. All sessions terminal.
Logs: /tmp/lean-usda-recursive-meta-{build,gates,reflection}.log.

RecursiveMetadataProofs is imported by UsdSpec. No executable model or C++
behavior changed. Complete subset metadata recovery is now proved, with lexical
key/delimiter/offset hypotheses retained. Whole supported AST and remaining
implementation/semantic audit requirements remain open. No commits, pushes or
reports filed.

Next concrete dependency: nested Prim/primItems recovery, then Layer. Scratch
/tmp/lean-usda-prim-assembly.lean compiled only mutual Prim.parserCost/itemsCost
and Prim.WellFormed/itemsWellFormed definitions (not repository source and not
recovery evidence). Prim.WellFormed accepts any quoted name, requires lexical
optional type, each metadata WellFormed, each attribute AttrWellFormed and all
child prims recursively. Suggested proof: simultaneous induction on parser fuel;
prim (f+1) calls primItems f, while primItems (f+1) calls prim f for a child and
primItems f for siblings. Prim print consumes the closing brace but leaves its
printed final LF; preserve that LF in the scalar inverse. Prove actual prim
header/type/name/optional-metadata prefix first using specifier_print_general,
str_print, primMetas_print_text and padding lemmas. Then recursive cost dominance
and actual prims/parseLayer assembly. Do not substitute these scratch definitions
for the required recovery theorem or close the whole-AST checkbox prematurely.

Prim/Layer assembly follow-up: PrimProofs.lean proves simultaneous recovery of
actual prim/primItems for arbitrary nesting and mixed child/attribute bodies,
with lexical optional types/attributes/metadata. Conservative recursive costs
are dominated by actual printed length; no depth/list/string bounds are added.
LayerProofs.lean proves arbitrary top-level prim sequence recovery, actual
sublayer bracket parsing and parseLayer_print under Layer.WellFormed, including
header, optional sublayers, order, whitespace, input-length fuel and EOF.

Completion audit found a remaining domain gap, so the whole-AST checkbox stays
OPEN: DVal stores String keys and the parser accepts quoted DictionaryKey,
but DVal.printItem emits keys bare. EntriesWellFormed therefore still restricts
keys to IdentLexeme, and the assembled theorem does not cover the full intended
key domain. /tmp/lean-usda-key-domain.lean passes two guards: a key-with-space
AST fails roundtrips, while its properly quoted text parses to that same AST.
Fix printer key quoting and broaden the key recovery proofs next; do not claim
full closure using the current identifier-only hypothesis. C++ already quotes
nonidentifier keys in PrintDictionaryIndented (value-printer.cc) and has a
quoted-key regression in test_writer.cc. No C++ behavior was changed here.

Final prim/Layer checkpoint: lake build PASS (3184 jobs), all 12 Lean gates
PASS in 67.63 s. Compiled axiom audit: 3088 theorems (491 private), 42 modules,
only propext/Classical.choice/Quot.sound. All 16 vector tables/consumers/drift,
reflection/PCP and negative trust tests pass. Reflection references 7/7 and
git diff --check pass. All sessions terminal; no executable model or C++ changes.
Logs: /tmp/lean-usda-prim-layer-{build,gates,reflection}.log. No commits, pushes
or reports filed. Overall goal remains active.

PrimProofs.lean and LayerProofs.lean are imported by UsdSpec. General nested
prim/body recovery, actual input-length fuel, top-level prim lists and actual
parseLayer_print are proved under explicit lexical Layer.WellFormed conditions.
Do NOT mark the general supported-AST checkbox complete: the completion audit
found a real dictionary-key domain gap (quoted String keys accepted by parser,
printed bare by DVal.printItem, excluded by EntriesWellFormed).
/tmp/lean-usda-key-domain.lean + .log independently confirm the counterexample:
quoted source parses to the AST; roundtrips for that AST is false. This is the
next required fix, not justification to restrict supported dictionary keys.

Next: implement model key quoting (always q, or bare identifiers plus q fallback),
then general key-parser/entry-step inverses without IdentLexeme key assumptions.
Broaden PrimitiveEntryWellFormed/EntriesWellFormed so arbitrary String keys work
at every depth, retaining numerical/type/offset lexical validity. Update actual
DVal.printItem and recovery proofs together; preserve existing theorem claims or
supply stronger replacements. Re-run whole Layer proof and domain audit. Add
key vectors/production consumer/stock checks including empty, spaced, punctuation,
Unicode, quote/backslash/control keys. Native next writer already has key_text
in src/next/writer/value-printer.cc:1304 and quoted-key fixture/assertion in
 tests/next/test_writer.cc:1330/1420; do not invent an unfounded native bug.
Only after keys are covered and requirements audited should the whole-AST item
be closed. Full PEG/NFC/spline/PCP/validators/vectors/final regressions remain
separate open plan items. Lean commands cwd verif/lean; no build/relink while
corpus/native tests launch the same binary. Current final gate logs terminal.

Final dictionary-key / supported-AST checkpoint:
- Fixed DVal.printItem to quote every String key. Bare-source prefix theorems
  remain; new quoted-prefix and stronger entry-step theorems have no identifier
  key assumptions. PrimitiveEntryWellFormed no longer restricts keys, and
  EntriesWellFormed_all proves every nested dictionary tree admissible.
- Whole Layer recovery compiles with arbitrary keys. The new unconditional
  parseLayer_print_dictionary corollary quantifies over every String key/DVal.
  Former spaced-key failure and nested Unicode/NUL computation checks pass in
  /tmp/lean-usda-key-domain-fixed.lean/.log. Constructor-by-constructor scope
  audit is doc/validation/lean-usda-roundtrip-audit.md. The supported operational
  AST/escaping checkbox is now closed; full normative PEG, semantic fidelity,
  NFC, spline and composition obligations retain their full original scope.
- Added seventeenth generated table usda-key-vectors.inc: 45 independently pinned
  keys x 3 entry kinds = 135 actual Lean Layer.print sources. Native consumer
  checks exact dictionary membership/type/nesting after source, USDA and crate.
  tests/next/test-usda-keys.py verifies its manifest independently and requires
  pinned stock 26.11 provenance. CI runs it next to the original string check.
- These cases exposed/fixed a real C++ writer bug: namespace:key was emitted
  bare and failed strict reparsing. value-printer.cc now quotes namespace
  separators. This is a DictionaryKey BaseIdentifier rule, not a schema change.
- Native Debug build and 100/100 CTests PASS87.78s. Final proof build PASS3184
  jobs; final12 Lean gates PASS67.53s. Audit3100 theorems493private42modules,
  only propext/Classical.choice/Quot.sound. All17tables drift/consumers and
  negative trust checks pass; native vectors39091checks0failures; reflection7/7.
- Stock key oracle135cases399semanticchecks129exactstockcrates6classified
  NUL-key truncations (native rejects all6). Original string40cases118checks
  38exactstockcrates2classifiedNUL-value losses also PASS. Initial proxy-equality
  test failure was corrected by materializing Sdf's dictionary proxy as dict;
  stock source parsing itself preserves NUL keys. No cases were removed.
- Stock PCP contract24/24PASS12.833s. All138compositioncases retained (3invalid
  roots+135compared): v1 121exact14allowed0unexpected; strict95exact40different.
  Exact40case set matches the previous baseline; strictzero ceiling still fails
  and remains OPEN, not waived. No allowlist pruning or expectation weakening.
- Source checksum core_spec.md/LICENSE OK. git diff --check and reflection pass.
  No commits, pushes or issue reports filed. All tool/build/test sessions terminal.
Logs: /tmp/lean-usda-keys-{final-proof-build,final-gates,full-native,stock,
stock-strings,stock-pcp,corpus,final-reflection}.log. Proof/docs status updated;
constructor audit and reflection matrix distinguish Lean recovery from tested
native reflection, without claiming general C++/Lean parser equivalence.

Next useful full-plan work: return to remaining LightUSD composition/validator
items (40strict/14engine cases, relocate validation/order rules/spec-version
metadata and relationship default crate transport), or complete another open
formal audit obligation. Do not reopen/restrict dictionary keys to make proofs
or tests easier. Global module/73finding audit, literal/compat split, NFC,
spline bounds/KeepRatio, richer prim-index model, more reflection vectors, strict
PCP CI and broad final serial/threaded/Python/WASM/legacy/roundtrip work remain.
WASM/Python follow-up for the shared dictionary writer fix is not claimed done.


Order/relocate validation follow-up: added recommendation-level warning rules
core.layer.primOrder, core.prim.primOrder, core.prim.propertyOrder. They validate
identifier versus namespaced-property syntax, allow speculative missing names,
preserve source vectors and make no unsupported duplicate-order restriction.
Registry records expose all three. Lean population algorithms do not establish
name grammar, so no misleading lean_ref was attached.

Existing relocate authoring checks now run over LayerMeta::relocates as well as
legacy prim metadata. Pseudo-root targets are rejected; root-prim targets and
empty deletion targets remain valid controls. Findings carry <layer> rather
than an invented prim location. Source/root/ancestor/pairwise composition gaps
remain OPEN; this is not full Relocates.validRelocates reflection.

Current-state audit also confirmed kSpecVersion already v1.1.0 and genuine crate
mutation tests in test_crate_dict.cc exercise duplicate-key diagnostics, last
value retention and strict crate rejection. These are verified existing work,
not newly implemented in this follow-up. Targeted validator/registry/report
CTest 3/3 passes. Full next Debug native suite is running; final evidence follows.

Final order/relocate-authoring validator checkpoint:
- New registry rules core.layer.primOrder, core.prim.primOrder,
  core.prim.propertyOrder issue warnings for malformed names. Missing children
  remain permitted, namespaced property names remain permitted, source vectors
  are preserved and the core group toggle disables all three. No artificial
  membership/duplicate-name constraint or unsupported Lean reflection was added.
- ValidateRelocates now has a shared vector overload. LayerMeta::relocates is
  validated at <layer>; the prim wrapper retains legacy behavior. Absolute
  property/relative sources, identities, duplicate sources and pseudo-root
  targets are covered. Root-prim targets and empty deletion targets are controls.
  Source root-prim, ancestor/descendant and pairwise/cross-stack checks remain
  OPEN; do not equate this with full Relocates.validRelocates or change stock's
  root-target compatibility (LEAN-515).
- Current-state audit confirmed existing genuine-crate duplicate dictionary
  tests exercise tagged validation findings, last-value retention and strict
  rejection. next_test_crate_dict passes in the full run. kSpecVersion was
  already v1.1.0; the checker help banner was stale v1.0.1 and is now corrected
  to1.1.0, preserving the compatible older profile alias. The combined duplicate/
  order/spec-version ledger item is closed; remaining relocation item stays open.
- Native next Debug full100/100PASS87.24s, including all12Lean gates. Test-only
  core-toggle assertion added afterward passes finalvalidator/registry/report
  3/3PASS0.10s. Compiled proof audit3100theorems493private42modules allowed3
  standard axioms; nativevectors39091checks0failures; reflection7/7.
- Built updated Release checker in build_ninja/checker and verified --dump-rules
  exposes all three new recommendation rules. Checker CLI contract47checksPASS,
  including help version, source order diagnostics/default versus strict exit,
  layer relocate rule IDs and <layer> locations. Rebuilding current source
  exposed stale strict fixtures in nested variants, rel-radius and URI asset
  cases; added required statement separators, preserving their exact intended
  semantic findings and expected exits. No parser rule or expectation weakened.
- doc/testing-cpp.md documents behavior and limitations; git diff --check passes.
  All build/test handles terminal. No commits, pushes or reports filed.
Logs /tmp/lean-order-relocate-{build,native,final-tests,checker-final-build,
checker-contract,final-reflection}.log; /tmp/lean-order-relocate-rules.txt is the
human-readable checker dump (not JSON). Validator-only change did not alter
PCP/cache/writer code; prior 138-case/40strict-difference baseline is not claimed
newly re-run in this checkpoint. Global goal remains active.

Next concrete work: complete relocation authoring rules/accurate component Lean
links and fix production BuildStackRelocates gaps against isolated stock oracle.
Inspect current helper overload in usd-validation-compose.cc and layer call in
ValidateLayerMetas. Source/root (compat OkRootOpenUsd), target-under-source,
ancestor/nested-source, non-one-to-one and cross-entry target/source policy
require careful literal/compat distinction. Avoid blanket root-prim TARGET
rejection. For composition duplicate-source behavior, verify layer-strength
semantics before globally rejecting sources across sublayers: an authored
conflict and a stronger replacement are different questions. Strict PCP still
has40cases and engineallowlist14; no silent waiver. Other full-plan formal and
final broad regression obligations stay intact.


Relocate selection follow-up: BuildStackRelocates now validates individual
candidate prim paths before source selection/pairwise conflicts. First valid
source opinion wins in strong-to-weak layer order, including deletion; invalid
strong opinions do not mask valid weaker entries. Root-relative names are
anchored at /. Layer fields supersede same-layer legacy prim edits, including
explicit empty fields. Stock clean v26.11.1 layerStack.cpp and isolated 26.11
runtime supplied the policy evidence. General relative-path normalization and
full authoring/semantic validator coverage remain separate open work.

The new stock regression matrix exposed the original weaker-target winner and
invalid-entry poisoning. Controls preserve parser rejection for invalid variant
paths; stock also rejects pseudo/property path fields and legacy prim relocates
at layer read. These cases are explicitly retained as rejections/native extension
controls, not silently dropped or called ordered-parity cases. C++ programmatic
invalid-source tests bypass text parsing and preserve valid imported content.
Full Debug native100/100PASS84.69s. Final proof/PCP gates and stock contracts are
running; terminal evidence follows. No corpus expectation or allowlist changed.

Final relocate-source-selection checkpoint:
- BuildStackRelocates filters individual invalid prim paths/identities/root
  sources/ancestor-descendant targets BEFORE first-valid-per-source selection
  and pairwise target/source conflicts. Layer iteration is strong-to-weak;
  weaker duplicate sources no longer replace stronger targets or deletes.
  Invalid stronger entries permit valid weaker fallback and cannot poison
  independent valid entries through a common target. Root-relative names are
  anchored at /. Same-layer authored root relocates (even empty) suppress
  legacy prim edits, matching the tagged collector's field-presence policy.
- Existing local-source/strict-ancestor arc guard and surviving pairwise/
  source-origin logic were retained. General relative-path normalization is
  NOT proved or claimed: this change tests ordinary root-relative paths.
- Clean v26.11.1 layerStack.cpp confirms validate-before-try_emplace and
  root-layer field precedence. Isolated usd-core26.11 runtime confirms valid
  strongest-source, stronger-delete, invalid-identity fallback, explicit-empty
  stronger-layer and root-relative controls with complete ordered v2 stacks.
- Tests retain stock rejections for variant/property/pseudo-root path fields and
  obsolete per-prim relocate text. Native variant parsing rejects; permissive
  native property/pseudo-root metadata composes only valid surviving edits.
  Legacy native extension precedence is tested separately, not mislabeled as
  stock text parity. No candidate cases were removed to obtain passing output.
  Programmatic C++ cases cover property/variant/pseudo/root/empty sources that
  bypass parser checks, retaining valid imported value7 at /P/New.
- Native Debug full100/100PASS84.69s, including serial/parallel PCP. Final stock
  PCP contract27/27PASS16.121s (new matrix has 5 valid strength controls,
  5 invalid-path controls and 3 legacy-extension controls). Final12 Lean/PCP
  gatesPASS66.43s. Compiled audit3100theorems493private42modules allowed3standard
  axioms; vectors39091checks0failures; all17table drift/consumers/reflection and
  negative trust checks pass. Reflection7/7 and git diff --check pass.
- Supplemental corpus retained all138 (3classifiedinvalid+135compared):
  v1 121exact14allowlisted0unexpected; strict95exact40different. Exact40case
  set equals prior baseline. Strictzero ceiling still exits1 as expected; no
  new waiver or allowlist change. This fix addresses additional scenes, not a
  claim of corpus closure.
- Updated Relocates.lean reflection COMMENT to current native policy; literal
  definitions/theorems were not changed. doc/testing-cpp.md records coverage
  and native-extension/rejection distinction. Full authoring validator rules,
  accurate component reflection, full literal/compat model separation and
  global module/73finding audit remain OPEN. No commits/pushes/reports filed.
  All build/test sessions terminal. Goal remains active.
Logs /tmp/lean-relocate-selection-{before,full-build,native,final-contract,
corpus,lean-build,final-gates,reflection}.log. Native production code changed
only src/next/pcp/cache-layers.cc in this checkpoint; test/PCP diagnostic script
and relocation reflection comment also updated. Checker build tree was NOT
rebuilt for this cache change; its previous validator snapshot remains from
prior checkpoint. Rebuild before using it as the current composition oracle.

Next: remaining authoring-level relocate rules and policy-accurate Lean refs;
then continue composition differences. Keep root-prim TARGETS valid for stock
compatibility (LEAN-515). Source conflicts across layers select the strongest
valid opinion, so do not globally mark every repeated source invalid. Distinguish
local authored duplicate-source diagnostics from layer-stack composition.
General parent-relative/legacy-path normalization and composition error reporting
still deserve audit. Broad serial/threaded/legacy/Python/WASM and full final
regressions remain required before overall closure.

Final relocate-authoring component checkpoint:
- Implemented all planned local authoring IDs root, ancestor,
  targetUnderSource, nestedSource, duplicateSource, plus duplicateTarget and
  explicit compatibility targetIsSource/targetUnderOtherSource. Existing
  identity/source/target diagnostics remain. Root-prim targets and multiple
  deletion targets remain valid; path prefix checks use component boundaries.
  Parent-source lookups avoid an unconditional all-pairs scan. Both layer and
  legacy prim metadata use the shared local-field validation helper.
- Added separate Lean OkSourcesUnique/OkTargetsUnique and proved their conjunction
  equivalent to existing literal OkOneToOne. Added named OpenUSD compatibility
  OkOtherSourceOpenUsd/OkTargetNamespaceOpenUsd without replacing literal
  per-entry OkSame/OkBelow. Nine new component references (16 total) resolve
  exactly through the compiler/checker; no whole-validRelocates equivalence is
  implied. Native raw malformed paths are handled by separate syntax checks.
- Public report category compatibility now identifies the two cross-entry
  OpenUSD policies; normative-only filtering excludes them. Source-root errors
  remain normative (so literal filtering cannot hide those), while the root
  reference explicitly names OkRootOpenUsd/LEAN-515 and permits root-prim
  TARGETS. Literal/global model separation remains open beyond these components.
- Native tests cover each rule in layer and prim scopes, authored locations,
  multiple deletes, component-boundary controls, post-relocated descendant
  namespaces, component refs/categories and normative-only filtering. Checker
  CLI tests cover all new rules, references and profile exit behavior.
- Native Debug full100/100PASS88.02s, including all12Lean gates. Updated checker
  CLI63checksPASS. Reflection16/16 exact; compiled audit3101theorems493private
  42modules, only propext/Classical.choice/Quot.sound. Vectors39091checks0failures;
  all17table drift/runtime and negative trust gates pass. Lean build3184jobsPASS.
  git diff --check passes. All builds/tests terminal. No commits/pushes/filings.
- Both build_ninja/next_debug and build_ninja/checker were rebuilt from current
  C++ source (checker now includes the preceding cache/source-selection fix).
  docs/testing-cpp, checker README and REFLECTION describe local authoring scope,
  component references and compatibility classification. Whole relocation and
  global semantic/model audits remain OPEN; no overall goal completion claim.
Logs /tmp/lean-relocate-rules-{lean,final-native-build,final-checker-build,native,
cli,reflection}.log and /tmp/lean-relocate-rules-registry.txt. This checkpoint
changed validators/metadata plus component Lean definitions/proof, not PCP cache
composition logic. Previous retained corpus is138cases with40strict differences;
it was not newly re-run just for authoring/category-only changes.

Next concrete follow-up: composed relocation/error policy and general relative
path normalization. Root-relative native composition is tested against stock,
but raw authoring metadata/legacy parent-relative normalization deserves audit
before claiming total relocation closure. Avoid globally invalidating repeated
sources across sublayers: source selection chooses the strongest valid opinion.
Keep local authored-field predicates distinct from contributor selection, and
root-prim targets valid for LEAN-515. Remaining40strict/14engine corpus cases,
full literal/compat split, module/73finding audit, NFC/spline/prim-index formal
work, further vectors/CI and broad final regressions still retain full scope.

Relative-relocate anchoring checkpoint:
- Shared AnchorRelocatePath handles root-relative and leading-parent prim paths
  in USDA layer/legacy prim metadata, authoring validation, PCP cache and USDC
  writer. Validation uses temporary anchored paths and preserves raw metadata.
  Strict parsing rejects above-root input; permissive parsing warns/preserves
  it and composition ignores the whole entry. Writer rejects in serial and
  parallel workers; failed anchoring never aliases an invalid target to delete.
- Tests cover helper matrix/Unicode/reflexive/underflow, strict/permissive USDA,
  canonical crate roundtrips, nested parallel fragment owner paths, late writer
  shards, programmatic root/parent-relative composition and invalid target
  retention of the source. Stock PCP contract now has28tests: an explicit
  malformed-input control records stock26.11 converting above-root target to
  empty deletion; Core L3370–3375 already prohibits this, so it is not a spec
  issue or valid-input parity claim. Legacy prim fields remain native extension.
- Native Debug100/100PASS94.05s (all12Lean gates), focused writer/validator2/2
  PASS16.12s, checkerCLI63PASS, pinned stock28/28PASS16.436s. Both native and
  checker trees rebuilt. Reflection16/16, spec+LICENSE checksums and diffcheck
  pass. No new Lean theorem/model changes in this checkpoint.
- Retained138composition cases:3classifiedinvalid+135compared. Engine baseline
  121exact14allowlisted0unexpected; strict95exact40different, EXACT same40case
  set as preceding source-selection baseline. Zero strict ceiling intentionally
  exits1; do not waive or call corpus closure. Report16 REVIEW now explicitly
  separates its absolute cross-entry rule from malformed relative anchoring.
- Logs /tmp/lean-relocate-anchor-{final-native,checker-build,worker-focused,
  native,cli,stock-final,corpus}.log. All builds/tests terminal. No commits,
  pushes or upstream filings. No unrelated staging files removed after a
  transient sandbox ENOSPC startup failure; normal sandbox operation recovered.
Next: composed relocation/error policy and remaining40strict/14engine cases;
continue all other unchecked formal/module/73finding, Unicode/spline/prim-index,
relationship-default crate, vector/CI and broad final regression work. Relative
anchoring implementation is covered, but total relocation closure remains OPEN.

Deferred inherited-variant stack checkpoint:
- Fixed GetPrimStack pending empty-option emission: inherited variants precede
  the dependent host variant at actual variant, reference/payload and terminal
  flush points. Use persisted arc_sites depth (all composition hops, including
  same-stack inherits), not arc_chain (cross-stack trail). Flush completed
  sibling inherits before the next sibling spec and nested hosts in postorder;
  retain stronger hosts when emitting a class's own variant source.
- New stock contract controls empty/property options, dependent payload, sibling
  and nested inherits. Initial reverse-only/stack-depth approaches exposed by
  these controls were replaced; final30/30stockPASS20.862s. Full ordered prim
  and property stacks compared, including standalone class queries.
- Retained138cases:3classifiedinvalid+135compared. Final engine123exact,
  12allowlisted,0unexpected; strict97exact38different. Exactly the two cases
  TrickyVariantWeakerSelection2_root and TrickyVariantWeakerSelection4_root
  now match; no new strict difference cases. Removed both allowlist entries.
  Strict zero ceiling still fails (exit1); global composition closure is OPEN.
- Interim full native99/100 failed only because the resolved allowlist entry
  required pruning; final full run uses the pruned allowlist. No Lean source or
  theorem changes; reflection16/16PASS and diffcheckPASS. Checker tree has NOT
  been rebuilt for this prim-stack-query change; it retains preceding anchoring
  checkpoint. Source under review is cache-opinions.cc plus contract/allowlist
  and testing docs. No commits/pushes/filings. Full original scope unchanged.
Logs /tmp/lean-variant-final-{stock,corpus,native}.log and
/tmp/lean-variant-postorder-final-build.log. Final native100/100PASS95.05s, including all12Lean gates. All build/test
sessions terminal. The checker tree limitation above remains explicit.

Independent ancestor-variant implied-inherit checkpoint:
- ProcessArc no longer skips an implied class target that exists only in an
  independently selected ancestor variant of the expressing stack. Derive its
  child sources from SourcesForSite(parent), compose their namespace mappings,
  offsets and suppression into the implied arc, and expand them at the implied
  strength position. The direct-target reuse shortcut must not bypass this
  propagation when an expressing stack has an independent ancestor variant.
- Independence is checked in composed namespace: if the target parent also
  contains the inheriting prim, retain the existing prim-index selection
  context. An initial unconditional ancestor expansion introduced an extra
  tidscene opinion in TrickyInheritsInVariants2; that candidate was corrected,
  not allowlisted. The final corpus returns that case to matching.
- New contract checks root ancestor selections z/x/empty/absent against the
  referenced stack's y selection, including exact property-stack provenance
  without relying on the optional stock comparison. Pinned stock31/31PASS
  19.066s. Final native100/100PASS94.49s, including all12Lean gates.
- Retained138cases,3classifiedinvalid+135compared:124engineexact11allowlisted,
  0unexpected;98strictexact37different. Exactly SubrootInheritsAndVariants_root
  removed from the preceding38strict set, no new strict difference cases.
  Pruned its allowlist entry. Strict zero ceiling still exits1; no waiver.
- Native and checker trees rebuilt, including the preceding empty-option
  prim-stack fix. CheckerCLI63PASS; reflection16/16 and diffcheckPASS. No Lean
  source/proof changes or formal completeness claim. Testing docs updated.
- Final pruned corpus confirms124engineexact11allowlisted0unexpected and
  98strictexact37different; exact delta only SubrootInheritsAndVariants_root.
  Strict zero ceiling intentionally exits1. All builds/tests terminal. Logs /tmp/lean-implied-independent-{native,final-corpus,final-build,
  checker-build,cli,final-stock}.log (stock actual final log is
  /tmp/lean-implied-independent-final-stock.log). No commits/pushes/filings.
Full original scope remains open, including remaining37strict/11engine cases,
all-module/73finding audit, literal/compat split, Unicode/spline/prim-index,
relationship-default crate, further vectors/CI and broad final regressions.

Subroot implied-strength-anchor checkpoint:
- Reference/payload target grafts preserve target_src.implied_anchor unless an
  enclosing implied block already owns it. Specializes retain their weak
  position (do not promote with inherits). Previously the implied opinions
  existed but appeared after the referenced local site because the graft lost
  their anchor. No new source/site fabricated; fix is actual source strength.
- Added complete stock property-stack control with conflicting values across
  root implied inherit, referenced local/inherit and root/direct specializes.
  Stock32/32PASS19.555s. Native value controls cover both root implied11 winner
  and referenced local22 winner when no root inherit value exists. Corrected
  fixture arc syntax to <path> after its first failure; native PCP now passes
  inside full run. Initial unrestricted anchor propagation promoted specializes
  incorrectly; final excludes them and stock control detects that distinction.
- Retained138cases:3classifiedinvalid+135compared,124engineexact11allowlisted
  0unexpected,100strictexact35different. Exactly SubrootReferenceAndClasses_root
  and SubrootReferenceAndVariants2_root now match from prior37set; no new
  differing cases. Neither was in the lossy engine allowlist, so no pruning.
  Strict zero ceiling still fails(exit1); broader composition closure OPEN.
- Native full100/100PASS90.08s, including all12Lean gates; actual composed value
  controls both PASS. All build/test/download sessions terminal.
  Log/tmp/lean-subroot-inherit-final-native.log.
  Build/tmp/lean-subroot-inherit-final-build.log terminal; stock and corpus logs
  /tmp/lean-subroot-inherit-anchor-{stock,corpus}.log. Reflection16/16 and
  diffcheckPASS. Checker tree not rebuilt for this anchor change. No Lean proof
  changes, no commits/pushes/filings. Six-hour deadline remains11:39:44UTC.
Next independent provenance work has downloaded official Unicode15.1.0 UCD
reference data into ignored build_ninja/unicode-15.1.0. SHA256 results are in
current tool output; must create checked-in version/hash manifest and independent
reader/checker before claiming provenance closure. One-off full-range comparison
of DerivedCoreProperties.txt confirms C XIDStart667/Continue776 exactly match
Unicode15.1.0. Native C source comment incorrectly says5.1.0. Lean XID generator
currently copies C, so it still lacks independent generation. NormTables currently
comes from host Python Unicode16.0 (2081canonical entries), not pinned15.1.
General NFC idempotence remains OPEN; fetching data is not a proof. Files fetched:
DerivedCoreProperties,UnicodeData,DerivedNormalizationProps,NormalizationTest,
ReadMe, all .txt. No external data committed; no unrelated files removed.

Pinned independent Unicode checkpoint:
- Added verif/lean/data/unicode-15.1.0.json with official HTTPS base and SHA256
  for DerivedCoreProperties,UnicodeData,DerivedNormalizationProps,
  NormalizationTest,ReadMe. Fetch script caches under ignored
  build_ninja/unicode-15.1.0, verifies cached/downloaded bytes, never silently
  accepts corrupted cache. Common lean_unicode_ucd.py reads only pinned files.
- XID generator now derives667Start/776Continue ranges independently from
  DerivedCoreProperties and separately rejects native C mismatch. Normalization
  generator reads UnicodeData+Full_Composition_Exclusion, no host unicodedata.
  Norm tables now spec-pinned15.1:2061decompositions388CCCranges941compositions
  85two-character exclusions (removed Unicode16-only20decompositions etc).
  Native XID membership unchanged; corrected stale5.1 comments to15.1.
- Added Lean Check.Unicode executable using ACTUAL nfcCps/nfdCps against all
  19074official rows (10checks each), plus identity on1095035scalars omitted
  fromPart1. Total2380810checks0failures. This is exhaustive pinned conformance,
  NOT a general symbolic idempotence proof. General NFC requirement staysOPEN;
  split combined ledger row so completed provenance is explicit, not inferred.
- Trust script checks both generatedtables/native parity and four negative
  controls:corruptsource,nativedrift,generateddrift,missingreference. AllPASS.
  Both Python3.11 and3.14 reproduce tables exactly. Lean build3184jobsPASS;
  all17generatedvectortables no drift; reflection16/16PASS; checkerCLI63PASS.
- Registered next_lean_unicode_conformance (requires verified UCD cache; setup
  fetch documented in testing-cpp/Lean README). CI caches manifest-keyed data,
  fetches/verifies, runs trust and actualLean conformance gates; native XID
  sourcepaths now trigger workflow. lakefile adds usdspec-check-unicode.
- Native/checker rebuilt; full native now101tests/13Lean gates. Final native
  101/101PASS131.58s, including all13Lean gates; Unicode conformance gatePASS.
  Session35419 terminal; log/tmp/lean-unicode-final-native.log. Other build,
  conformance, vector, checker, download sessions terminal. Logs
  /tmp/lean-unicode-{pinned-build,full-conformance,trust,vectors,native-build,
  checker-build,cli}.log. No commits/pushes/filings; no external datasets tracked.
Next: general NFC proof and spline KeepRatio/value bounds, full module73finding
and literal/compat audit, richer prim-index, remaining35strict/11enginecases,
relationship-default crate, vectors/CI and broad final regressions. Source
Normalize.lean still has a historical Python16 XID-closure observation paragraph
(not the new table source); audit/update that claim when doing its module audit.
Six-hour hard stop remains2026-11-06 11:39:44UTC (started05:39:44UTC). Reserve
final regression/audit time; do not shrink original plan or claim full closure.

Spline certification checkpoint:
- Actual curveSegValue now calls named Seg.keepRatio (same rational formula,
  no changed evaluation output). General bisect_bounds, sqrtLo_nonneg/sq_le,
  keepRatio_underapprox, keepRatioScale_safe and Seg.keepRatio_safe prove
  positive non-lengthening scale and non-regression for arbitrary fuel,
  nonnegative widths and positive duration. Fuel zero included; no assumed
  exact rational square root or sampled-only validity claim.
- New SplineBounds module proves real cubic Lipschitz bound from control
  coefficients, rational/real evaluation bridges, real root existence in each
  final bracket by continuity, and strict monotonicity/uniqueness for a positive
  duration non-regressive time cubic. The nonconstant-polynomial argument
  handles isolated zero derivatives at Keep Ratio boundaries.
- keepRatio_root_unique establishes existence/uniqueness for in-range target
  times. keepRatio_value_error bounds the ACTUAL corrected-segment midpoint
  against its unique real time root by K/2^(n+1), for arbitrary n. No rational
  root or positive derivative lower bound assumed. At fuel64, bound K/2^65.
  K=abs(A)+2abs(B)+3abs(C) for value cubic polynomial coefficients. Full proof
  assumptions/code linkage in doc/validation/lean-spline-bounds-audit.md.
- Formal spline-bounds/KeepRatio ledger requirement now complete for rational
  model. Native C++ floating-point rounding is separate, not claimed proven.
  Hermite/time-linear exact branch retains its prior theorem; other spline
  semantic/module audits remain open under the full73finding scope.
- Lean fullbuild3267jobsPASS; all13Lean CTest gatesPASS70.78s. Compiled audit
  3141theorems493private43modules; onlypropext/Classical.choice/Quot.sound.
  All17vectortables unchanged; actual native vector consumer39091checks0failures;
  combine-chain58PASS, Unicode2380810PASS, axiom negative6/6PASS,
  reflection16/16PASS. All10legacy spline testsPASS. diffcheckPASS.
- Logs /tmp/lean-spline-certified-{build,gates,legacy}.log. All build/test
  sessions terminal. No native behavior/source modifications this checkpoint;
  last full native101/101 snapshot is preceding Unicode checkpoint. No commits,
  pushes or filings. README counts and REFLECTION updated, including current
  retained corpus124engineexact11allowlisted/100strictexact35different.
Next: full module73finding/literal-compat audit, general NFC idempotence, richer
prim-index proofs, remaining35strict/11enginecases, relationship-default crate,
vectors/CI and broad final native/Python/WASM regressions. Six-hour hard stop
remains2026-11-06 11:39:44UTC; current checkpoint around06:10UTC.

Prim-index arc-edit/global-payload checkpoint:
- PrimIndex PrimSpec now supports reference/payload/inherit/specialize optional
  ListOp opinions. Legacy nonempty lists mean explicit opinions, empty legacy
  lists mean absence; some(explicit[]) is an authored clear. authoredArcs now
  merges each field with actual ListOp.chain/iterate, not concatenation.
  General mergeArcOpinions_eq_foldr connects this computation to normative
  weak-to-strong application; explicit and clear absorption are proved.
- Added actual payload arc kind/expansion and global composeWithLoadPolicy
  LoadAll/LoadNone. withoutPayloads removes payload opinions throughout the
  source layers, preserves other fields, and is proved idempotent. Selective
  loading, incremental load-cache behavior and deferred metadata are not modeled.
- Gen.Vectors.PrimIndex emits prim-index-vectors.json by ACTUAL compose calls:
  4arcfields*8strongops*4weakops*2loadpolicies=256cases. Parent+ancestralchild
  queries total512 paths, with exact ordered prim/property stacks and child
  absence after clear/deferral. Marker properties validate provenance. Consumer
  does not reimplement editing; native production lusdcat and pinned stock agree
  for all256cases/512queries. New generatedJSON243973bytes, 18thartifact; existing
  17.inc tables unchanged. No physical fixture captures tracked.
- Native consumer registered next_lean_primindex_vectors, labels lean/pcp/generated;
  CI runs both native and stock. Oracle helper now optionally omits payload
  requests for --defer-payloads; default behavior remains LoadAll. Existing
  32stockCLIcontractsPASS27.325s. Model audit added at
  doc/validation/lean-prim-index-audit.md; full richer-model requirement staysOPEN.
- Full native102/102PASS113.35s, all14Lean gatesPASS. Compiled audit3153theorems
  493private43modules, onlyClassical.choice/Quot.sound/propext. All18generated
  artifacts no drift, native vectorconsumer39091PASS, Unicode2380810PASS,
  reflection16/16PASS and diffcheckPASS. No new native C++ logic this checkpoint.
- Retained138compositioncases remain3classifiedinvalid+135compared:
  124engineexact11allowlisted0unexpected;100strictexact35different, EXACT same
  strict35case set. Zero strict ceiling intentionally exits1, not waived.
- Logs /tmp/lean-primindex-{edits-build,loaded-vectors-gen,loaded-full-build,
  loaded-stock,vectors-native-build,final-native,final-stock-contract,final-corpus}.log.
  All sessions terminal; native56989, stock20570, corpus93835 finished. No commits,
  pushes or filings. Checker tree not rebuilt for this Lean/Python-only change.
Next: remove fuel-as-cycle-policy/add reporting and termination invariants,
expand implied class authored arcs, relocation model, variant provenance;
continue full73finding/literal-compat audit, general NFC proof, remaining35strict/
11enginecases, relationship-default crate, other vectors/CI and broad final
regressions. Deadline remains2026-11-06 11:39:44UTC; current around06:28UTC.

Finite sublayer traversal and initial-diagnostic checkpoint:
- Replaced fuel-bounded layerStack with layerStackVisit, a branch-local DFS
  terminating by available-layer Finset.card. Each recursive child erases its
  parent; sibling branches keep independent sets, preserving repeated legal
  diamonds. Missing and cyclic edges emit LayerStackIssue and no layer entries,
  per verified Core L4264–4269. No arbitrary layer-depth cutoff remains in model.
  The legacy fuel parameter is retained but layerStack_fuel_independent proves
  it irrelevant. Native max-depth/resource policy remains a separate option.
- General proofs: layerStackVisit_mem, layerStackVisit_excludes,
  layerStack_mem_known; missing/cycle exact-result equations and well-founded
  recursion. Existing six worked examples/old fuel-stability controls stillPASS.
  Prim-arc expansion/cycle policy is STILL fuel-bounded; full rich-model goalOPEN.
- New Gen.Vectors.LayerStack emits layer-stack-vectors.json (44794bytes), the
  19thgenerated artifact.94graphs:25two-node,64three-node,diamond,shared cyclic
  diamond,missing sibling,cycle+missing,25-layer chain. Native and pinned stock
  agree on all layer orders, complete prim/property stacks and required
  diagnostics. Diagnostic COUNT parity not claimed (stock repeats cached errors).
  New next_lean_layerstack_vectors registeredCTest/CI; defaultartifactdriftgate
  nowchecks19files. Existing256arc/load cases stillPASS after new traversal.
- This exposed real native diagnostic loss: old Cache::Open recorded typed
  cycle issues but discarded initial warning/error TEXT, so CLI omitted it.
  Retained original four-arg symbol and added explicit five-arg warning-output
  overload (nm confirms BOTHsymbols). CLI, common composition helper and
  session opens use it. Nonfatal initial load errors append to warnings; fatal
  errors remain expected-error results. Unreadable sublayers now ALSO emit a
  typed InvalidAssetPath, including with no output string requested.
- Expanded native API regression for warning append/prefix, cycle stream+typed
  issue, missing-layer typed diagnostic, permissive surviving root and strict
  failure. Old four-arg calls remain throughout suite. This is a LightUSD
  diagnostic fix, not an AOUSD defect. No upstream report filed.
- Native full103/103PASS97.23s, including all15Lean gates. Compiled audit3190
  theorems496private43modules; onlyClassical.choice/Quot.sound/propext. Native
  vectors39091PASS,19artifactdriftPASS,Unicode2380810PASS,axiomnegativesPASS,
  reflection16/16PASS,diffcheckPASS. CheckerCLI63PASS. Existing stock32contracts
  PASS22.393s. Retained138corpus=3classifiedinvalid+135compared;124engineexact,
  11allowlisted,0unexpected;100strictexact35different, SAME35case set. Strict
  zero ceiling exits1 as before. Native and checker rebuilt from currentsource.
- Disk incident: repo mount reached58MBfree and sandbox startup failed. Moved
  ONLY task-owned ignored build_ninja/legacy_debug (3.1GB) to
  /tmp/lightusd-lean-builds-4ijkd1rk/legacy_debug; original path is a symlink.
  No sources/binaries/unrelated staging deleted. All10legacy spline tests pass
  through original path. Repo now~3GBfree,tmp~15GBfree; monitor further builds.
- Logs /tmp/lean-sublayer-{certified-build,vectors-stock,final-native-build,
  final-checker-build,final-vectors,final-native,final-cli,final-stock-contract,
  final-corpus,cache-legacy-spline}.log. All sessions terminal:77398native,
  26061stock,45809corpus. Earlier pending/error logs superseded by these results.
  No commits,pushes,filings. README/REFLECTION/testing/model audit updated.
Next: prim-arc cycles/finite expansion, implied class authored arcs/relocates/
variant provenance, full73finding and literal-compat audit, general NFC proof,
remaining35strict/11enginecases, relationship-default crate, furthervectors/CI,
full final native/Python/WASM regression. Hard stop11:39:44UTC unchanged.

Finite prim-arc and specializes-order checkpoint (2026-11-06 07:40 UTC):
- Prim-arc expansion now removes the active source site from a finite branch-local
  set; termination is by `available.card`, and repeated/ancestor targets on the
  same layer are skipped with `ArcCycle` diagnostics. Added a diagnostic-carrying
  direct-expansion/composition path (`addDirectChecked`,
  `composeTreeWithChecked`, `composePrimIndexChecked`); the main API remains
  source-compatible. Kernel proof checks a self-reference diagnostic and root
  retention. Fuel-independence proofs cover raw expansion, direct expansion and
  tree construction. Variant-context and relocation-origin cycles remain outside
  this raw-site identity model.
- Strength ordering now processes complete specializes cohorts before weaker
  sibling cohorts. Kernel regression gives `A, B, D, C` for A specializing B/C
  where B specializes D. Native PCP and pinned OpenUSD 26.11 controls from the
  preceding probe agree. Path-renamed origin families and mapped inherit
  class-diamond coalescing remain open; no completeness claim.
- Polished AOUSD draft 20: removed the unsupported claim that `queue.pop()` is
  necessarily LIFO; it now states the queue discipline is unspecified and no
  strength-order step is provided. Independent stock/formal evidence retained;
  no issue filed. Reflection and prim-index model audit describe the new proofs
  and explicitly retain model limits.
- `lake build`, `lake exe usdspec-test`, generator drift check (all 19 artifacts),
  all 15 Lean CTest gates PASS. Compiled theorem audit: 3,228 theorems, 499
  private, 43 modules; only `propext`, `Classical.choice`, `Quot.sound`.
  Native+stock: prim-index 256 cases/512 queries PASS; layer-stack 94 graph/error
  cases PASS; existing PCP JSON stock controls 32/32 PASS. Native full suite and
  broad value/legacy/Python/WASM regressions remain outstanding.
- No C++ source changes this checkpoint, no commit/push/report filing, no change
  to the vendored AOUSD specification. Overall plan remains open.

Specializes class-diamond and full native checkpoint (2026-11-06 08:00 UTC):
- Pinned stock and native PCP showed a real duplicate specializes-class source:
  A specializes B/C, both specialize D; LightUSD emitted D and D's property
  twice while stock emitted them once. `cache-arcs.cc` now coalesces only repeated
  `Specialize` sources with matching stack/site, implied anchor, arc kind and
  mapping restricted to the class subtree. It preserves first/strongest order.
  At that checkpoint inherit, reference and payload multiplicity remained
  untouched. Added a stock-
  backed PCP JSON regression for both prim and property stacks.
- A broader class-source rule caused 3 unexpected engine changes in relocation
  and reference cases. It was narrowed to specialize sources, then the namespace
  map key was scoped to the class subtree. Final result passes all ratchets:
  native legacy PCP 124 exact + the same 11 documented allowlist entries + 0
  unexpected across 135 compared cases. Strict lossless stock comparison is
  103 exact / 32 different (was 100/35); exactly these three cases then matched:
  `SpecializesAndAncestralArcs5_root`, `TrickyNestedSpecializes_root`,
  `TrickySpecializesAndRelocates_root`. The strict zero-difference ceiling still
  exits 1 and has not been waived.
- Full Debug build PASS. Full CTest 103/103 PASS, including all 15 Lean gates and
  the new class-diamond test. Lean audit: 3,228 theorems (499 private), 43
  modules, only `propext`, `Classical.choice`, `Quot.sound`. Stock-backed PCP JSON
  controls 33/33 PASS; prim-index 256 cases/512 queries and layer-stack 94
  graph/error cases PASS native and stock. All 19 generated artifacts remain
  drift-free from the earlier check. Logs `/tmp/lean-class-diamond-{full-build,
  final-native,corpus4}.log (the 103/32 result is superseded below).
- Updated the Lean reflection and prim-index scope audit. Issue 20 now describes
  queue discipline as unspecified rather than asserting LIFO. No issue filed,
  commit or push; vendored spec unchanged. Full module/73-finding audit, general
  NFC proof, remaining strict/engine differences, relationship-default crate,
  and final Python/WASM/legacy/broad value regressions remain open.

Exact-map inherit coalescing checkpoint (2026-11-06 08:10 UTC):
- The final native rule also coalesces repeated `Inherit` class sources, but
  only when the complete namespace mapping matches. This resolved seven more
  corpus cases without changing any engine-ratchet result. A broader
  subtree-normalized inherit identity caused three unexpected engine diffs and
  was rejected. A simple inherit diamond with different mappings remains
  uncoalesced.
- Latest corpus: engine PCP ratchet 124 exact + the same 11 documented
  allowlisted cases + 0 unexpected, across 135 comparisons. Strict stock parity
  is 110 exact / 25 different (up from 103/32); the seven additionally resolved
  cases are `ErrorInvalidConflictingRelocates_root`,
  `TrickyConnectionToRelocatedAttribute_root`,
  `TrickyInheritsAndRelocates2_root`, `TrickyInheritsAndRelocates5_root`,
  `TrickyMultipleRelocations3_root`,
  `TrickyMultipleRelocationsAndClasses2_root`, and
  `TrickyMultipleRelocationsAndClasses_root`. The strict zero-difference gate
  still fails; no allowance was added.
- Latest-source native Debug build and CTest PASS (103/103). Stock-backed PCP
  JSON controls pass 33/33; prim-index vectors pass 256 cases/512 queries and
  layer-stack vectors pass 94 cases, native and pinned stock. `git diff --check`
  passes. Reference/payload multiplicity is preserved, while inherit sources
  use exact full-map identity.
- Logs: `/tmp/lean-class-final-full-build.log`,
  `/tmp/lean-class-final-native.log`, `/tmp/lean-class-final-corpus.log`.
  Source changes remain uncommitted; no push, report filing or vendored spec
  edits. Full issue/finding audit and remaining validation are still open.

Python suite check (2026-11-06 08:18 UTC):
- Rebuilt the editable abi3 extension from current `src/next` sources with
  `python3 setup.py build_ext --inplace`. The documented pip editable-install
  command is blocked by the system interpreter's PEP 668 policy.
- Full suite from `python/`: 557 passed, 22 skipped, 49 failed. Rebuilding did
  not change the outcome. Failures are parse errors on one-line USDA fixtures
  missing required prim-body or metadata statement separators (`;` or newline);
  strict parser behavior is intentional and matches the OpenUSD grammar. These
  fixtures need cleanup for the suite to be a valid regression gate. No tracked
  Python binary was added.

Registry and report audit (2026-11-06 08:20 UTC):
- Mechanical scan found 73 unique rows, 73 exact Lean source IDs, no missing
  tags and no unregistered IDs. All 21 local numbered report drafts are present.
  This does not verify every line citation or source/runtime claim, so the full
  73-finding semantic audit remains open. Issue 20's independent review remains
  `FILE`; no report has been filed.

Inherit-diamond probe and rollback (2026-11-06 08:27 UTC):
- A minimal valid inherit diamond (`A -> [B,C]`, `B/C -> D`) shows stock emits
  D once while native emits it twice. A subtree-only inherit key matches this
  case but causes three unexpected strict corpus diffs in relocated inherit
  cases; checking only the class source stack for relocates did not avoid them,
  because relocation context can come from elsewhere in the composition.
- Reverted the trial and test. Restored corpus ratchets are 124 exact + the same
  11 allowlisted + 0 unexpected; strict parity remains 110/135 with 25 diffs.
  A provenance-aware inherit identity remains open; no regression allowance was
  added. Log: `/tmp/lean-class-safe-final-corpus.log`.

Continuation validation (2026-11-06 08:43 UTC):
- The strict-USDA Python fixture cleanup is complete. Full suite from `python/`
  now passes: 606 passed, 22 skipped, 10 deprecation warnings (46.93 s). The
  earlier 557/22/49 result is superseded; no parser behavior was weakened.
- Rechecked `/tmp/lean-child-raw-order`: current native PCP output is
  `b, a, u, v`, matching stock. Existing committed coverage includes small and
  40-child cases across USDA/USDC. Focused PCP contract and serial/parallel PCP
  tests pass.
- Current Lean and PCP gates pass 12/12, including Lean build/runtime, axiom
  audit, reflection, Unicode, vector drift and prim-index/layer-stack vectors.
- Re-ran the 138-case composition corpus against pinned stock: v1 124 exact,
  11 allowlisted, 0 unexpected; strict lossless 110 exact / 25 different. The
  zero-difference ceiling remains unmet. Log:
  `/tmp/lean-continuation-final-corpus.log`. Updated the stale count in
  `verif/lean/REFLECTION.md`.
- `git diff --check` passes; AOUSD issue 20 remains locally reviewed as FILE,
  with no upstream report or vendored-spec edit. Full 73-issue semantic audit,
  strict PCP parity, and remaining broad regression/proof work remain open.
- The registry check exposed missing source annotations for LEAN-515 and
  LEAN-801. Added the tags beside the corresponding theorem/note; registry now
  reports 73 tags OK, reflection reports 16/16 resolved, and diff-check passes.

ListOp admissibility audit (2026-11-06 08:54 UTC):
- Re-read Core L1271-1483. The `combine` equations and ordering clauses match
  the source, including the append-last example. Added `ListOp.WellFormed` to
  express uniqueness per explicit/composable sequence (without disallowing
  permitted cross-field overlap), and proved `apply_nodup` for unique weaker
  lists. Reflection table updated.
- Full `lake build` (3267 targets), `usdspec-test`, all 19 generated artifact
  checks, and the compiled Lean axiom gate pass. C++ sources unchanged in this
  proof step. Broader high-risk module audit and general NFC proof remain open.

Dictionary and layer-offset transcription review (2026-11-06 08:56 UTC):
- Dictionary merge L1241-1255 matches the four bullets. Stronger-side entry
  ordering is explicitly an implementation representation choice, since the
  spec defines dictionaries as unordered. Recursive key uniqueness is modeled
  by `WellFormed` and preserved by `merge_wf`; shape compatibility is required
  for associativity. LEAN-101 correctly records the spec's unconditional
  associativity contradiction. No new mismatch found.
- Recursive TCPS L5466-5509 correctly adjusts only scale by parent/sub-layer
  rates then composes under accumulated offset. Closed-form proof is restricted
  to scale; LEAN-112/113 limitations remain documented. No new mismatch found.

Child ordering and relocated arrivals review (2026-11-06 08:59 UTC):
- Core L5952-6004 and `Population.Children` match the literal ordered-prefix
  pseudocode; LEAN-603 documents stock's different run-preserving reorder. Native
  PCP uses the stock-compatible algorithm and composes each spec order after
  accumulating its raw child names.
- Pinned stock and LightUSD both order relocated extension names `Item10` before
  `Item2`, while Core calls for path-element sorting. Added a stock-backed
  `test_relocated_child_extensions_follow_stock_path_order`; contract passes.
  This is a further Path/Order spec-versus-stock discrepancy; no AOUSD draft or
  vendored text was changed.

Specifier and clip-time transcription review (2026-11-06 09:00 UTC):
- Core L6118-6131 matches the formal scan and C++ `ComposeOpinions`: skip
  `over`, direct-inherit `class` is tentative, and a defining `def` wins.
  LEAN-701 correctly preserves the bullet overlaps/gaps and stock counterexamples.
- Core L6962-6994 and L7222-7236 match the Lean piecewise-linear mapping, clamp,
  and right-most duplicate-knot behavior. Empty-time identity (LEAN-768) is a
  documented compatibility choice; clamp-region value interpolation divergence
  stays separately recorded under LEAN-769. No additional transcription issue
  found in these checks.

Crate PATHS validation review (2026-11-06 09:01 UTC):
- Core L11950-11984 and the Lean encoder/decoder agree with OpenUSD preorder
  path rows and jump semantics. General encode/decode round-trip is proved at
  row-count fuel; LEAN-413 documents the literal spec's jump-zero divergence.
- Native crate reader checks token/path bounds, duplicate indices, jump range,
  positive jump target, and allocation limits before its iterative traversal.
  Formal malformed-table validation and total-vs-encoded path-count invariants
  are not proved and remain separate audit scope. No valid-input mismatch found.

ListOp composition closure proof (2026-11-06 09:05 UTC):
- Added `combine_wellFormed` to prove the Core L1421-1483 combine operation
  preserves per-sequence uniqueness for both composable-over-explicit and
  composable-over-composable inputs. Permitted overlap between distinct
  composable fields is still represented.
- `lake build UsdSpec.ListOp`, full `lake build` (3267 jobs), `usdspec-test`,
  and generator drift check for all 19 artifacts passed. The compiled axiom
  gate passed 1/1 (67.46 s); registry check reports 73 tags, reflection is
  16/16 resolved, and `git diff --check` passes.
- Reflection row updated. No LightUSD production or AOUSD text changes in this
  proof-only step. Remaining accepted work is still open.

Relocated destination squatter fix (2026-11-06 09:16 UTC):
- `DeriveChildSources` now keeps only exact destination-site grafts after a
  relocate arrival. Same-stack inherited/reference sources below the target
  are part of the ancestral subtree and must be elided, as in OpenUSD
  `_EvalNodeRelocations`. This fixes `TrickyRelocationSquatter_root` and also
  removes the extra implied-class site previously seen in `bug69932_root`.
- Added a stock-backed inline regression. Both focused `next_pcp_json_contract`
  and the corpus case pass. Pruned `bug69932_root` from the v1 allowlist after
  its XPASS.
- Latest composition corpus: 138 total (3 verified invalid + 135 structural),
  v1 **125 exact / 10 allowlisted / 0 unexpected**, strict v2 **112 exact / 23
  differing**. Strict zero-difference remains unmet. Log:
  `/tmp/lean-relocate-squatter-pruned-corpus.log`.
- Native suite rerun is active at session 44516 after a first run's sole XPASS
  was pruned; targeted supplemental CTest is 1/1 PASS. Preserve that handle.

Relocation fix validation complete (2026-11-06 09:18 UTC):
- Full standalone Debug CTest passed **103/103** in 81.63 s, including serial
  and parallel PCP, stock-backed JSON contract, supplemental ratchet, Lean
  gates, preview and workflow tests. The earlier 102/103 XPASS run is
  superseded.
- Corpus remains v1 **125 exact / 10 allowlisted / 0 unexpected** and strict
  v2 **112 exact / 23 differing**. Strict lossless parity remains open; no
  allowlist is used for strict differences.
- Lean issue tags (73), reflection references (16/16), and `git diff --check`
  pass. The broader full-plan work remains active.

ListOp reduction invariant (2026-11-06 10:27 UTC):
- Added `reduce_wellFormed`; `WellFormed` is now proven preserved by
  `combine`, `reduce`, and application to a unique weaker sequence. Updated the
  reflection table.
- Lean-labeled CTest passed **15/15**, covering generated vectors, runtime,
  PCP contract and axiom audits. Registry/reflection checks pass (73 tags,
  16/16 references); diff check is clean.
- Audited `TrickySpecializesAndInherits_root` against the pinned oracle. Its
  remaining strict mismatch is implied-specialize origin coalescing/order; no
  production change was made without a bounded, regression-safe rule. The
  latest strict PCP baseline remains 112 exact / 23 differing.

Relocation case review (2026-11-06 10:29 UTC):
- Reproduced `ElidedAncestralRelocates_root` against stock 26.11. It shows
  LightUSD still attributes `/Char/Anim/Collision` to the elided
  `/CharBase/Anim/Collision` arrival and retains an extra child stack entry.
  This is distinct from destination-squatter filtering: the intended `/Char`
  relocation source is delivered through an ancestral reference and must
  supersede that earlier relocate. The current source expansion does not
  clearly identify the winner from this fixture alone, so no speculative code
  change was made. The case remains in both current difference sets as
  documented.

Mapped ancestral relocate arrival (2026-11-06 11:07 UTC):
- Resolved the preceding `ElidedAncestralRelocates_root` mismatch in
  `DeriveChildSources`: root-stack relocation arrivals are now looked up in
  the arc-mapped parent namespace, with a raw-source fallback only when that
  arrival maps to the child being composed. This lets the stronger relocated
  source delivered through the ancestral reference win over the stale
  `/CharBase` spelling. Same-stack source suppression now recognizes both raw
  and mapped parents; the fallback preserves the destination-squatter case.
- Removed `ElidedAncestralRelocates_root` from the v1 allowlist after its
  stock and LightUSD result became exact. The composition corpus now reports
  **126 exact / 9 allowlisted / 0 unexpected** across 135 structural cases
  (138 total including 3 verified invalid roots). Strict stock v2 reports
  **113 exact / 22 differing**; its zero-difference ceiling remains unmet.
  The new relocate case, `TrickyRelocationSquatter_root`,
  `PayloadsAndAncestralArcs3_root`, `RelocatePrimsWithSameName_root`, and
  `TrickyMultipleRelocations4_root` all match stock in focused checks.
- Added `test_ancestral_relocate_arrival_supersedes_elided_source` to the PCP
  JSON contract, reproducing the selected-variant/ancestral-reference pattern
  inline. All 36 PCP JSON contract tests pass with the pinned stock oracle;
  the CTest contract passes in `build_ninja/next_debug`, `build-next`, and the
  threaded `build_next_dbg` tree.
- Focused PCP/supplemental CTest passed **4/4**; full `build_ninja/next_debug`
  CTest passed **103/103**. The two additional standalone Debug trees rebuilt.
  Their parallel full runs were resource-contended: `build-next` had two
  light-filter tests fail and `build_next_dbg` had the instance-group timing
  threshold fail; all three passed when rerun individually after contention
  ended. The threaded PCP serial/parallel tests passed in both runs.
- Lean issue registry (73 tags), reflection check (16/16), reflection checker
  tests, and `git diff --check` pass. The signed-zero AOUSD draft was re-read;
  it remains locally polished and not filed. No vendored AOUSD text changed.
- Current strict differences are still spread across specializes/inherits,
  relocation multiplicity, class-source origins, and layer-stack ordering.
  Latest full-corpus log: `/tmp/lean-mapped-relocate-final-corpus.log`.

Strict relocation multiplicity trace (2026-11-06 11:30 UTC):
- Follow-up trace of `TrickyMultipleRelocations_root` shows the duplicate
  `/SubRig` source is introduced in two relocated-content traversals that reach
  `/Char/Rig2/SubRig2` through distinct root-stack mappings (`/Char/Rig2/SubRig`
  and `/Char/Rig/SubRig`). Each traversal independently contributes the same
  `subrig.usd` site and arc context. Destination dedup currently scopes to one
  `DeriveChildSources` call, so it cannot merge this cross-traversal duplicate.
  No broader source coalescing was applied: it needs a provenance-aware rule
  that preserves genuinely distinct arc contexts.


Chained-relocate duplicate fixed:
- Relocated content already contains expanded reference sources. Passing those
  sources through ExpandList expanded their own arcs again, duplicating the
  referenced prim and property stacks. Src now marks such content as already
  expanded; fresh child sources still expand their own arcs normally.
- Added inline chained-relocate/reference regression. All 37 PCP JSON contract
  tests pass with pinned stock OpenUSD 26.11.
- Full composition corpus: 126 exact / 9 allowlisted / 0 unexpected against
  checked expectations; strict stock improves to 118 exact / 17 differing.
  TrickyMultipleRelocations_root now matches stock exactly. Strict zero ceiling
  remains unmet for the other 17 cases. Log: /tmp/chained-corpus.log.
- Final full Debug CTest passed 103/103 (78.46 s), including serial/parallel
  PCP, supplemental composition and all Lean gates. Reflection resolves 16/16;
  git diff --check passes. Log: /tmp/chained-ctest.log.


Selected variant override at relocate destination fixed:
- Destination collision filtering now retains selected variant sources owned by
  the relocating stack when the variant owner is an ancestor of that destination.
  This preserves authored variant property overrides ahead of relocated content.
- Added inline prim/property-stack regression with a selected variant override
  and relationship. All 38 JSON contract tests passed with pinned OpenUSD 26.11.
- Final 138-case corpus: 127 exact / 8 allowlisted / 0 unexpected; strict stock
  119 exact / 16 differing. TrickyVariantOverrideOfRelocatedPrim_root now matches
  and its stale allowlist entry is removed. Strict zero ceiling remains open.
  Log: /tmp/variant-arrival-final-corpus.log.
- Final full Debug CTest passed 103/103 (81.15 s), including serial/parallel
  PCP and all Lean gates. Reflection resolves 16/16; diff check is clean.
  Log: /tmp/variant-arrival-final-ctest.log.


Referenced relocation source opinions fixed:
- Composed relocation source expansion now suppresses root-stack opinions at
  the old source path before expanding arcs, including when the relocate is
  authored in a referenced stack. Legal destination opinions remain intact.
- Added inline regression; all 39 JSON contract tests pass with pinned OpenUSD.
- Full 138-case composition corpus: 128 exact / 7 allowlisted / 0 unexpected;
  strict stock 120 exact / 15 differing. BasicRelocateToAnimInterface_root now
  matches and is pruned from the allowlist. Strict zero ceiling remains open.
  Log: /tmp/relocate-source-root-corpus.log.
- Final full Debug CTest passed 103/103 (73.78 s), including serial/parallel
  PCP, supplemental and all Lean gates. Reflection resolves 16/16; diff check
  passes. Log: /tmp/relocate-source-root-ctest.log.


Implied-specialize grouping probe (2026-11-07, reverted):
- `BasicSpecializesAndInherits_root` differs because the implied specialize
  hierarchy at the expressing ancestor stack (root `/Specializes_2` plus the
  inherit implied beneath it, `/Inherits_2`) must precede the origin stack's own
  specialize hierarchy (`ref.usd /Specializes_2`, `/Inherits_2`). We interleave
  by arc type: root Spec2, ref Spec2, root Inh2, ref Inh2.
- A blanket stable partition of implied entries ahead of non-implied entries in
  `ExpandList`'s specialize list fixes that case but regresses
  BasicSpecializes, SpecializesAndVariants4 and TrickyNestedSpecializes{,2}
  (strict exact 120 -> 117, 3 new v1 unexpected). Reverted; no source change
  retained. A correct rule needs per-origin-subtree grouping (group an implied
  inherit with the implied specialize of the same origin), not a global
  partition.


NFC idempotence sweep (2026-11-07):
- `Check/Unicode.lean` now also runs a bounded exhaustive sweep with the actual
  Lean `nfcCps`/`nfdCps` over a 1332-scalar alphabet (every composition
  component, every ccc>0 scalar, Hangul boundary samples): all ordered pairs
  plus triples (starter, mark, mark) over 40 sampled marks, 3,800,196 strings.
  Checked nfc(nfc x)=nfc x, nfd(nfc x)=nfd x, nfd(nfd x)=nfd x: 0 failures,
  with the 19,074-row conformance corpus still 0 failures (27 s total).
- This is stronger evidence, NOT a symbolic proof. The general theorem needs
  table invariants (e.g. composites of non-starter decompositions, ccc of
  recomposed characters) that are not yet stated in Lean; the ledger item
  "General NFC idempotence" stays open. `canonicalOrder_idem` remains the only
  proved ordering component.


Prim-index model invariants and mechanism vectors (2026-11-07):
- New `UsdSpec/Composition/PrimIndexInvariants.lean`: extension site laws,
  implied-copy laws (class arcs only, all flagged implied), variant-selection
  provenance (`selSource`, `selFrom_eq_selSource`, weaker sites never override),
  relocate-source pruning (`pruneTrees_sites`) and the cycle-report theorem.
- Generator `prim-index-mechanism-vectors.json` (6 cases: implied inherit with
  and without root override, payload loaded/deferred, strong/weak variant
  selection) passes native and stock 26.11. The variant case exposed a toy-model
  defect (variant-set names duplicated across layers); fixed by name union.
- Still open in this item: implied class nodes expanding their own arcs,
  relocates integrated into `compose`, variant-context cycles.


Track B checkpoint (2026-11-07):
- Citation audit gate `check-lean-spec-citations.py` (CTest `next_lean_spec_citations`,
  CI): 73 rows, 0 bad citations, 0 unverified quote fragments after fixing 10
  registry quotes (LEAN-112/201/204/411/412/413/742/769 and the Metadata CLAIM).
- Model split gate `check-lean-model-split.py` (CTest `next_lean_model_split`, CI).
- NFC symbolic idempotence is NOT proved; bounded sweep evidence only (see above).
- Prim-index model: invariants + 6 mechanism vectors added (see above); relocates
  are not yet integrated into `compose`.

Prim-index follow-through (2026-11-07):
- `composeImplied` (implied classes expand arcs authored at the implied site) and
  `composeRelocated` (relocated-away prims and source-path nodes suppressed;
  `composeRelocated_away`, `composeRelocated_nil`) added. Vector `implied-chain`
  matches native PCP and stock 26.11 (7 mechanism cases). Still unmodeled in
  Lean: relocation destination mapping and variant-context cycles, so the
  prim-index item stays unchecked.
- NFC: reduction identified. nfc(nfc x)=nfc x follows from nfd(nfc x)=nfd x
  (then composeCps sees the same input). That lemma needs table facts (each
  primary composite decomposes to its two parts; Hangul arithmetic) plus a
  blocking-invariant proof for `composeGo`; not done.
- The data-dependent premises are now machine-checked in the compiled
  `usdspec-check-unicode` gate (15,519 checks, 0 failures): every table composite
  decomposes to its parts' full decompositions, full decomposition is stable on
  its outputs, and Hangul composition inverts decomposition on all 11,172
  syllables. Kernel `decide` over these tables did not finish in 15 minutes, so
  they are executable checks, not theorems.

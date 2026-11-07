# Prim-index model follow-up

The executable `UsdSpec.Composition.PrimIndex` model now merges reference,
payload, inherit and specialize lists across a layer stack using the proved
ListOp implementation. `mergeArcOpinions_eq_foldr` connects that computation to
weak-to-strong normative list application. Explicit lists replace weaker lists;
explicit empty lists clear them. An absent opinion contributes no operation.
The legacy convenience fields represent nonempty explicit lists; an authored
empty clear uses `some (.explicit [])` in the edit field.

Payload arcs have their own strength kind and are expanded like reference arcs.
`composeWithLoadPolicy` supports global LoadAll and LoadNone. LoadNone removes
payload opinions throughout the source layers while preserving the other fields;
`withoutPayloads_idempotent` proves this transformation idempotent. This is not
a model of selective per-composed-prim load rules or incremental cache updates.

`Gen.Vectors.PrimIndex` computes expected stacks by calling the actual prim-index
composer, rather than merely applying a list operation in the generator. It
emits `tests/next/generated/lean/prim-index-vectors.json`. The matrix has four
arc fields, eight stronger operations, four weaker operations and two payload
policies: 256 cases. Each queries both `/P` and `/P/Child`, exercising ancestral
opinions as well as direct arcs. Marker properties on every target check property
provenance in the same order. Empty expected child stacks require namespace
absence; the consumer does not accept an unexpected empty placeholder prim.

`test-prim-index-vectors.py` runs the production `lusdcat --dump-pcp-json` path
and compares complete ordered prim/property stacks with the Lean results.
The optional pinned official OpenUSD oracle performs the same checks for all
cases in one process. Global deferral uses the existing native `--defer-payloads`
flag and omits Pcp payload requests in the oracle. Existing oracle behavior
remains LoadAll by default. The consumer does not reimplement list editing.
Case count and unique identifiers are checked to prevent accidental coverage
reduction. The regular Lean generator drift gate verifies the checked-in JSON.
CTest and the Lean CI workflow run the native consumer; CI also requires stock.

Sublayer construction is now independent of the legacy fuel argument.
`layerStackVisit` recurses on a branch-local finite available-layer set and its
cardinality strictly decreases. Missing layers and excluded ancestors produce
explicit `LayerStackIssue` values and no layer entries, matching Core
L4264–4269. `layerStackVisit_mem` proves that every emitted layer was available
on branch entry; `layerStackVisit_excludes` prevents excluded ancestors from
reappearing. `layerStack_mem_known` rules out unknown layer entries, and
`layerStack_fuel_independent` establishes independence from arbitrary depth fuel.
Sibling branches reuse their own available set, so valid diamond graphs repeat
a shared sublayer rather than applying an incorrect global deduplication.

`Gen.Vectors.LayerStack` emits `layer-stack-vectors.json`: 94 exhaustive/targeted
graphs, including two/three-node cycles, missing siblings, legal diamonds,
shared cyclic branches and a 25-layer chain. The consumer checks layer order,
prim/property provenance and required diagnostic presence against native and
pinned stock PCP. Diagnostic counts are not compared because stock may return
the same stack error from multiple prim-index requests. CTest and CI require
the new consumer; the drift gate covers this nineteenth generated artifact.

The graph tests found a native CLI warning gap. The existing four-argument
`Cache::Open` symbol is retained; an explicit five-argument overload appends
initial sublayer warning/nonfatal-error text. Composition helpers, sessions and
the PCP JSON CLI use it. Unreadable sublayers now also produce a typed
`InvalidAssetPath` issue. Permissive loads keep valid layers; strict missing-asset
policy still fails. API tests check warning append behavior, typed diagnostics,
surviving content and fatal returns. This is an implementation diagnostic fix,
not a new specification defect.

Authored arcs now use a finite set of known `(layer, path)` source sites. Each
active recursive expansion removes its source from the branch-local set, so
termination follows from `Finset.card`; a repeated site or a target ancestor on
the same layer is reported as `ArcCycle` and omitted from the tree. `expandChecked`
exposes diagnostics for an individual expansion. `addDirectChecked`,
`composeTreeWithChecked` and `composePrimIndexChecked` carry rejected-cycle
diagnostics through the composed prim index. Legacy fuel parameters remain for
API compatibility; `expand_fuel_independent`, `addDirect_fuel_independent` and
`composeTreeWith_fuel_independent` show that these paths do not use depth fuel as
a cycle policy. A kernel-checked self-reference example verifies both the
diagnostic and retention of the noncyclic root node. This raw-site rule does not
model variant-context identity or relocation-origin cycles.

`Strength.levelsBy` now drains complete specializes cohorts before a weaker
sibling cohort. This fixes the nested case `A specializes [B, C]`, `B specializes
D`: the required order is `A, B, D, C`, also checked against native PCP and
stock OpenUSD 26.11. `nestedSpecializes_sibling_order` proves this regression in
Lean. The basic model groups by site path; origin-aware identity can be supplied
through `strengthOrderBy`, but path-renamed source cohorts are not yet computed by
the prim-index builder. Inherit diamonds still need their distinct deduplication
and origin rules.

The native PCP composer coalesces repeated specializes class sources when the
layer stack, authored site, specializes arc kind, implied anchor and mapping
restricted to that class subtree agree. For inherit sources, it requires the
complete namespace mapping to match and uses the first/strongest occurrence.
This preserves reference/payload multiplicity and inherit opinions whose
namespace maps differ. A stock-backed regression checks the prim and property
stacks for the specializes diamond `A -> [B, C]`, `B -> D`, `C -> D`.
Across the retained corpus, strict parity rose from 100/135 to 110/135; the
native legacy PCP view remains 124 exact, 11 documented allowlist cases and
zero unexpected differences. A simple inherit diamond whose class maps differ
is still not coalesced; broader class provenance remains open.

The model still has substantial limits. Implied class copies do not expand their
own newly expressed authored arcs, inherit-diamond coalescing is incomplete,
relocates are absent, variant selection is two-pass rather than a full dependency
computation, and variant-set-name list editing is not implemented. Paths, asset
resolution and layer offsets remain abstract. The generated cases do not cover
all interactions among these mechanisms. The full prim-index requirement
therefore stays open; these proofs and fixtures do not establish whole-composer
equivalence or remove any retained native composition difference.

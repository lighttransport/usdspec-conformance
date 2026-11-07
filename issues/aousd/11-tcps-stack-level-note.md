# Time codes per second: clarify the accumulated offset in the stack-level note

**Type:** clarification
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Composition → Time Codes Per Second → Layer Stack Time Codes Per Second (L5455-5466)
**Formal reference:** `verif/lean/UsdSpec/LayerOffset.lean` — `stackLevel_offset_ne_recursive` (counterexample), `cumulative_scale_closed_form` (the scale part is true); registry `LEAN-112`

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

L5462-5467 (note):

> The per-sublayer and per-reference adjustments below produce the same
> effective offsets as computing the layer stack's timecodes-per-second divided
> by a layer's timecodes-per-second for each layer and composing the result
> with the layer's accumulated offset. The recursive formulation is normative;
> the stack-level description is provided for clarity.

### Observation

The scale telescopes to `∏ authored scales × rootTcps / layerTcps`.
For the offset, the note does not specify how its "accumulated offset" is
formed. If it means the composition of authored offsets before TCPS
adjustments, a single root/leaf ratio does not recover the recursive result.
Root `R` (24 tcps) sublayers `A` (48 tcps, offset 10) which sublayers `B`
(48 tcps, offset 5):

- recursive (normative): `⟨10, 1/2⟩ ∘ ⟨5, 1⟩ = ⟨12.5, 1/2⟩`
- stack-level: accumulated authored offset `⟨15, 1⟩` composed with the ratio
  `Q = ⟨0, 24/48⟩` gives `authored ∘ Q = ⟨15, 1/2⟩` or
  `Q ∘ authored = ⟨7.5, 1/2⟩`. Here `(F ∘ G)(t) = F(G(t))`.

The Lean counterexample checks precisely these two compositions of the
authored-only accumulated map. It does not refute an interpretation in which
the accumulated offset already includes the intermediate recursive TCPS
adjustments; that interpretation needs to be stated to make the note useful.

### What OpenUSD does

OpenUSD 26.11 places B's sample authored at 0 at stage time **12.5**
(`08-12-lean-demo/run.py`, line `11`), the recursive result. LightUSD agrees.

### Request

Define "accumulated offset" and its composition order explicitly, including
the effect of intermediate TCPS adjustments on descendant offsets. A plain
authored-only fold followed or preceded by the root/leaf ratio is insufficient.
Alternatively, restrict the claimed shortcut to the scale component or drop
the explanatory note; retain the normative recursive rule.

## Reviewer checklist

- [ ] Quoted note at L5462-5467 and the sublayer rule L5469-5491.
- [ ] Hand-compute the three offsets above.
- [ ] Run `08-12-lean-demo/run.py` (`R.usda`, `A.usda`, `B.usda`); confirm line `11`.
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "timeCodesPerSecond offset"`.

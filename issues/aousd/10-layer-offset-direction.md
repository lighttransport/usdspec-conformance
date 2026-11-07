# Layer offsets: the §12 example applies the offset in the wrong direction, and §10.3.1 adds the child's offset

**Type:** erratum
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Value Resolution → Attribute Resolution → Layer Offset and Scale (L6505-6526); Composition → Sublayers (L4282-4288); Time Codes Per Second (L5436-5440, L5483-5487)
**Formal reference:** `verif/lean/UsdSpec/LayerOffset.lean` — `apply_compose`, `inverse_apply`, the `LEAN-111` examples, `composeLiteral_ne`; registry `LEAN-111`, `LEAN-113`

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

L6514-6526, for `subLayers = [@./cueball.usda@ (offset = 10; scale = 0.5)]`:

> In this example if the current `timeCode` is 12 the time sample will be
> calculated `((12 * 0.5) + 10) = 16`, 16 being the new `timeCode` for
> sampling the animation in the sublayer.

L5436-5440 says the effective offset "converts [a layer's] time ordinates into
the root layer stack's time scale" and that value resolution uses it "to remap
their queries into each layer's time space", i.e. stage time = `offset + scale·layerTime`,
so a stage query needs the inverse map.

Separately, L4285-4288 says the effective offset is formed "by applying the
`scale` of the parent layer to the `offset` and `scale` of the child and then
adding the `offset` of the **child**", while L5483-5487 says "the parent's
`offset` is added". Only the latter composes the affine maps; read literally,
L4285-4288 drops the parent's offset.

### What OpenUSD does

OpenUSD 26.11 (`08-12-lean-demo/run.py`, layer samples at 4, 12, 16):

```
10 stage times of layer samples {4,12,16}: [12.0, 16.0, 18.0] | Get(12) = 2.0 (layer value at 4) | Get(16) = 1.0 (layer value at 12)
```

Stage time 12 samples the sublayer at `(12 − 10) / 0.5 = 4`, not 16. 16 is
the *stage* time of the sublayer's sample authored at 12. LightUSD agrees.

### Request

1. Fix the example: "if the current `timeCode` is 12, the sublayer is sampled
   at `(12 − 10) / 0.5 = 4`" (or: "a sample authored at 12 in the sublayer
   appears at stage time `12·0.5 + 10 = 16`").
2. In L4287-4288 change "adding the `offset` of the child" to "adding the
   `offset` of the parent", matching L5483-5487.

## Reviewer checklist

- [ ] Quoted text at L6514-6526, L5436-5440, L4285-4288, L5483-5487.
- [ ] Run `08-12-lean-demo/run.py` (uses `root.usda`/`sub.usda`); confirm line `10`.
- [ ] `SdfLayerOffset::operator*` and its use in `UsdResolveInfo` / `Usd_ResolveValues` at v26.11.1.
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "layer offset scale example"`.

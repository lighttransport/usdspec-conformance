# LEAN-111 — Layer offsets: the §12 example applies the offset in the wrong direction

**ID:** `LEAN-111` · **Status:** `confirmed` (drafted [10](../../issues/aousd/10-layer-offset-direction.md))

## Spec lines

- `core_spec.md` L6505-6537 (§12 example: `offset + scale·t` → 12 → 16)
- `core_spec.md` L5436-5440 (effective offset = layer→root affine map)
- `core_spec.md` L4285-4288 (apply parent scale to child offset/scale, then add the child's offset)
- `core_spec.md` L5483-5487 (the parent's offset is added)

## Lean declaration

`verif/lean/UsdSpec/LayerOffset.lean` — `apply_compose`, `inverse_apply`, the `LEAN-111` examples, `composeLiteral_ne`.

## Gap

§12 computes the sublayer sample time as `offset + scale·t` (12 → 16), i.e. the
*stage→layer* direction. §10 defines the effective offset as the layer→root
affine map, so a stage query at 12 reads the sublayer at `(12 − 10)/0.5 = 4`.
OpenUSD and LightUSD both follow §10. The §12 example is reversed.

## Repro (live in the workbench)

Layers `root.usda` + `sub.usda`:

```
#usda 1.0
( subLayers = [ @./sub.usda@ (offset = 10; scale = 0.5) ] )

#usda 1.0
def "P"
{
    double v.timeSamples = { 4: 2, 12: 1, 16: 3 }
}
```

Ops: `getTimeSamples /P.v`, `get /P.v t=12`, `get /P.v t=16`.

## Expected

| op | Lean model | LightUSD | OpenUSD 26.11 |
|---|---|---|---|
| `getTimeSamples /P.v` | stage times {12, 16, 18} | 12, 16, 18 | 12, 16, 18 |
| `get /P.v 12` | 2 (layer value at 4) | 2 | 2 |
| `get /P.v 16` | 1 (layer value at 12) | 1 | 1 |

## Native evidence

`issues/aousd/08-12-lean-demo/run.py` line 10 output:

```
10 stage times of layer samples {4,12,16}: [12.0, 16.0, 18.0] | Get(12) = 2.0 (layer value at 4) | Get(16) = 1.0 (layer value at 12)
```

## Requested upstream fix

1. §12: "if the current `timeCode` is 12, the sublayer is sampled at `(12 − 10) / 0.5 = 4`".
2. L4287-4288: change "adding the `offset` of the child" to "adding the `offset` of the parent", matching L5483-5487.
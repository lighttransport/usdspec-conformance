# BasisCurves varying-data size falls below the documented minimum for short pinned cubic curves

Local draft for OpenUSD. Observed with the official `usd-core==26.11` wheel.

## Schema and implementation gap

Pinned cubic BasisCurves support as few as two vertices. The OpenUSD
implementation comments say that varying data for short curves should use a
single segment with two values. For pinned cubic B-spline and Catmull–Rom
curves, `ComputeVaryingDataSize()` returns zero at two vertices and one at
three vertices. This affects cardinality checks for varying widths, normals,
and primvars.

The pinned/nonperiodic cubic branch computes `(count - 4) / vstep` with an
unsigned `vstep`. When `count < 4`, the unsigned conversion occurs before
the minimum check, so that check cannot clamp the negative difference to zero.
[OpenUSD v26.11.0 source](https://github.com/PixarAnimationStudios/OpenUSD/blob/v26.11.0/pxr/usd/usdGeom/basisCurves.cpp)

## Reproduction

Run `python repro.py` with OpenUSD Python bindings. Both bases gave these
results in OpenUSD 26.11.

| Vertices | Observed varying values | Source-documented intent |
| --- | --- | --- |
| 2 | 0 | 2 |
| 3 | 1 | 2 |
| 4 | 2 | 2 |
| 5 | 3 | 3 |

## Conformance decision

The Lean `UsdSpec.Domains.curveVaryingSize` model and the LightUSD
`geom.curves.widths` validator use the source-documented two-value minimum.
Please confirm the required cardinality for two- and three-vertex pinned
cubic curves and align the API result and schema documentation with that
decision. [Lean model](../../../verif/lean/UsdSpec/Domains/Validation.lean)

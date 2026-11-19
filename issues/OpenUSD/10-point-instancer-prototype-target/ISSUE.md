# PointInstancer silently omits prototype transforms for unresolved targets

Run `python repro.py` with OpenUSD 26.11. The direct target `/Prototype`
contributes its X translation of 4, giving an instance translation of 5.
With `/Instancer.route`, `GetForwardedTargets()` returns `/Prototype`, but
`ComputeInstanceTransformsAtTime()` uses the raw relationship target and
returns an instance translation of 1. An unresolved direct target behaves
the same way. All three calls return one transform.

The [PointInstancer API](https://openusd.org/release/api/class_usd_geom_point_instancer.html)
describes the relationship as an ordered list of prototypes and has an
option to include prototype transforms. It would be useful to document
whether forwarding is permitted and what evaluation guarantees for
unresolved targets. LightUSD's authored layer check diagnoses relationship
property targets as invalid prototype entries. In composed mode,
`lusdchecker` also diagnoses direct prim paths that do not resolve.

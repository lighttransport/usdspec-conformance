# Volume field paths can refer to missing prims

Run `python repro.py` with OpenUSD 26.11. `GetFieldPaths()` returns a
density entry both when the forwarded target names an existing OpenVDBAsset
and when it names a missing prim. The path query forwards relationships and
checks target cardinality and path shape. Callers that need usable fields
must also resolve those paths against the stage.

This is a validation coverage distinction between a reported binding path
and a usable volume field. LightUSD's composed checker warns with
`vol.volume.fieldTargetMissing` when the single forwarded prim path does
not resolve.

An inactive target has the same path-query behavior. Its prim exists but is
inactive, and LightUSD's composed checker and volume converter treat it as
unavailable.

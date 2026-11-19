# Clarify minimum vertex counts for linear BasisCurves

Local draft based on the official OpenUSD 26.11 Python wheel.

The topology validity table requires more than two vertices for linear
nonperiodic curves and more than three for linear periodic curves. The
surrounding text defines a linear segment with two vertices. The segment-count
table and OpenUSD's `ComputeSegmentCounts()` assign one segment to a two-vertex
nonperiodic curve and two segments to a two-vertex periodic curve.
[OpenUSD v26.11.0 BasisCurves header](https://github.com/PixarAnimationStudios/OpenUSD/blob/v26.11.0/pxr/usd/usdGeom/basisCurves.h)

Run `python repro.py` using OpenUSD 26.11.

| Authored vertices | Nonperiodic | Periodic | Pinned |
| --- | --- | --- | --- |
| 1 | 0 | 1 | 0 |
| 2 | 1 | 2 | 1 |
| 3 | 2 | 3 | 2 |
| 4 | 3 | 4 | 3 |

A reported segment count establishes how the API counts segments. It leaves
the validity and renderability of these short curves open. In particular, the
single segment reported for a one-vertex periodic curve would be degenerate.

Please clarify the minimum renderable vertex count for each linear wrap mode,
including whether a two-vertex periodic curve is permitted. LightUSD's added
complete-segment validator applies to cubic curves pending clarification of
the linear validity table.

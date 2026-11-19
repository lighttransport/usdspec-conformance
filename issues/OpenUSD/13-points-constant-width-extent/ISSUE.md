# Points extent ignores widths interpolation

Run `python repro.py` with OpenUSD 26.11. Two `Points` prims have the same
two points. One has vertex widths `[0.5, 1]`. The other has a single width
`[1]` with `interpolation = "constant"`.
`UsdGeom.Boundable.ComputeExtentFromPlugins` returns bounds for the vertex
prim. It returns `None` for the constant prim.

The `Points.widths` schema doc says the element count "will be determined by
its 'interpolation'". The PointBased class doc adds that "It's common for
authored widths and normals to have constant or varying interpolation."
`pxr/usd/usdGeom/points.cpp` `_ComputeExtent` instead requires
`points.size() == widths.size()`, so a legal constant (or uniform) width
produces no extent. `UsdGeomCurves::ComputeExtent` uses the maximum width,
whatever the count.

Expected: grow each point by its width looked up through the widths
interpolation, so a constant width applies to every point.

LightUSD's `ComputeExtent` (`src/schema/geom-boundable.cc`) currently matches
OpenUSD, so the conformance oracle
(`tests/next/test-domain-geom-runtime.py`, `ConstantWidth`) records this
behavior. It does not endorse it. Change both together once upstream decides.

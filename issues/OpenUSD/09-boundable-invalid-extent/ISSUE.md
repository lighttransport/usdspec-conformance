# ComputeExtent returns malformed two-corner bounds

Run `python repro.py` with OpenUSD 26.11. The Cube has three authored
extent samples. At time 0, OpenUSD warns that the one-corner array has the
wrong size and computes the cube bounds. At time 1 it returns the authored
pair with a reversed Y interval. At time 2 it returns the authored pair
with a NaN X maximum.

The [Boundable schema guide](https://openusd.org/release/user_guides/schemas/usdGeom/Boundable.html)
defines the entries as the local-space minimum and maximum corners.
`UsdGeomBoundable::ComputeExtent` checks the array length before returning
authored bounds. It could also diagnose malformed corners before passing
them to callers. LightUSD's `geom.gprim.extent` checks both cases at each
authored sample.

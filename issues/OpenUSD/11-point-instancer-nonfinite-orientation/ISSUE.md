# PointInstancer can return nonfinite transform matrices

Run `python repro.py` with OpenUSD 26.11. A unit quaternion returns one
finite transform. Replacing it with a quaternion containing NaN or
infinity returns one transform with nonfinite lanes and no diagnostic.

The [PointInstancer schema](https://openusd.org/release/api/class_usd_geom_point_instancer.html)
requires authors to provide unit quaternions. Invalid input here
demonstrates a runtime diagnostic and recovery gap. LightUSD reports
`geom.pointInstancer.orientation` during validation. Direct transform
evaluation uses identity rotation for a nonfinite or zero quaternion, so
finite position and scale can still produce a finite matrix.

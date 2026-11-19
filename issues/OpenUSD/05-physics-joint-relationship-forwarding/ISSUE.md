# Clarify relationship forwarding for physics joint body endpoints

Local draft based on the official OpenUSD 26.11 Python wheel.

The Joint schema describes `physics:body0` and `physics:body1` as
relationships to an Xformable. An authored relationship target can itself
be a relationship, and the generic USD forwarding API can resolve it to an
Xformable. The physics importer reads the unforwarded target and resolves
its body from that path. [Joint schema](https://openusd.org/release/api/class_usd_physics_joint.html)
[OpenUSD parser source](https://github.com/PixarAnimationStudios/OpenUSD/blob/v26.11.0/pxr/usd/usdPhysics/parseUtils.cpp)

Run `python repro.py` with OpenUSD 26.11. Directly targeting `/Body`
sets the imported `body0` to `/Body`. Targeting `/Links.body` also
returns `/Body` from `GetForwardedTargets()`, but the physics descriptor's
`body0` is empty.

Should physics joint endpoints be restricted to direct prim targets, or
should the importer resolve a forwarding relationship before selecting the
body? LightUSD's conformance diagnostic currently requires a direct
Xformable target, matching the importer's body lookup.

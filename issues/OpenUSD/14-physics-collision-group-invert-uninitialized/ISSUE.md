# CollisionGroupDesc.invertFilteredGroups is uninitialized

Run `python repro.py` with OpenUSD 26.11. A `PhysicsCollisionGroup` that does
not author `physics:invertFilteredGroups` is reported with
`invertFilteredGroups == True`. That inverts its filtering, so the group
collides only with its filtered groups.

In `pxr/usd/usdPhysics/parseDesc.h` the constructor of
`UsdPhysicsCollisionGroupDesc` does not initialize the `bool
invertFilteredGroups` member. The schema declares
`bool physics:invertFilteredGroups` with no fallback, so in
`parseUtils.cpp` `_ParseCollisionGroupDesc` the call
`GetInvertFilteredGroupsAttr().Get(...)` fails and leaves the member
indeterminate. The value depends on memory contents, and reading it is
undefined behavior. For merged groups only the representative's value is
kept, so the result also depends on which group of the merge set is
traversed first.

Expected: `false`, the documented default ("Normally, the filter will
disable collisions against the selected filter groups"). Fix: add `,
invertFilteredGroups(false)` to the constructor, as the other descriptors do
for their bool members.

LightUSD's `lightusd::ResolvePhysics` uses `false`. The conformance runner
`tests/next/test-domain-physics-runtime.py` compares this field only where it
is authored.

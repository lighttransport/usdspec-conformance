# Clarify usdPhysics simulation-owner cardinality

Local draft based on the official OpenUSD 26.11 Python wheel.

Both `UsdPhysicsRigidBodyAPI` and `UsdPhysicsCollisionAPI` describe their
`physics:simulationOwner` relationship as selecting a single PhysicsScene.
The stock physics importer retains multiple scene paths in a rigid body
descriptor, and its owner filtering enumerates those paths.
[Schema](https://github.com/PixarAnimationStudios/OpenUSD/blob/v26.11.0/pxr/usd/usdPhysics/schema.usda)
[Importer](https://github.com/PixarAnimationStudios/OpenUSD/blob/v26.11.0/pxr/usd/usdPhysics/parseUtils.cpp)

Run `python repro.py` with the OpenUSD 26.11 bindings. The descriptor contains
both `/SceneA` and `/SceneB`. This demonstrates import behavior. Which scene
or scenes actually simulate the body depends on the downstream consumer.

Please clarify whether multiple owners are supported and, if they are,
describe how collider ownership interacts with an ancestor rigid body's
owner list. LightUSD's validation checks known target types and preserves
lists without imposing a single-target diagnostic.

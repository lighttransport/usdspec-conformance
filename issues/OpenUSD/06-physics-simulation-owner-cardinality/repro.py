"""Show which simulation owners the OpenUSD physics importer retains."""
from pxr import Sdf, Usd, UsdGeom, UsdPhysics

stage = Usd.Stage.CreateInMemory()
for name in ("SceneA", "SceneB"):
    UsdPhysics.Scene.Define(stage, "/" + name)
prim = UsdGeom.Xform.Define(stage, "/Body").GetPrim()
body = UsdPhysics.RigidBodyAPI.Apply(prim)
body.CreateSimulationOwnerRel().SetTargets(["/SceneA", "/SceneB"])
data = UsdPhysics.LoadUsdPhysicsFromRange(stage, [Sdf.Path.absoluteRootPath])
descriptor = data[UsdPhysics.ObjectType.RigidBody][1][0]
print(Usd.GetVersion(), [str(owner) for owner in descriptor.simulationOwners])

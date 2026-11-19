"""Compare generic relationship forwarding with OpenUSD physics body lookup."""
from pxr import Sdf, Usd, UsdGeom, UsdPhysics

stage = Usd.Stage.CreateInMemory()
body = UsdGeom.Xform.Define(stage, "/Body")
UsdPhysics.RigidBodyAPI.Apply(body.GetPrim())
joint = UsdPhysics.RevoluteJoint.Define(stage, "/Joint")
alias = stage.DefinePrim("/Links", "Scope").CreateRelationship("body")
alias.SetTargets(["/Body"])
for target in ("/Body", "/Links.body"):
    joint.GetBody0Rel().SetTargets([target])
    forwarded = joint.GetBody0Rel().GetForwardedTargets()
    records = UsdPhysics.LoadUsdPhysicsFromRange(stage, [Sdf.Path.absoluteRootPath])
    descriptor = records[UsdPhysics.ObjectType.RevoluteJoint][1][0]
    print(target, [str(path) for path in forwarded], repr(str(descriptor.body0)))

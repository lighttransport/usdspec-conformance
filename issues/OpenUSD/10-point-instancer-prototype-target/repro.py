"""Compare direct, forwarded, and unresolved prototype targets."""
from pxr import Usd, UsdGeom

stage = Usd.Stage.CreateInMemory()
prototype = UsdGeom.Xform.Define(stage, "/Prototype")
prototype.AddTranslateOp().Set((4, 0, 0))
instancer = UsdGeom.PointInstancer.Define(stage, "/Instancer")
instancer.GetPrim().CreateRelationship("route").SetTargets(["/Prototype"])
instancer.CreatePositionsAttr([(1, 0, 0)])
instancer.CreateProtoIndicesAttr([0])

relation = instancer.CreatePrototypesRel()
for path in ("/Prototype", "/Instancer.route", "/Missing"):
    relation.SetTargets([path])
    transforms = instancer.ComputeInstanceTransformsAtTime(0, 0)
    print(path, relation.GetForwardedTargets(),
          [tuple(matrix.ExtractTranslation()) for matrix in transforms])

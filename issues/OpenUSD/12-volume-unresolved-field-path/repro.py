"""Compare the field path map with stage prim resolution."""
from pxr import Usd, UsdVol

stage = Usd.Stage.CreateInMemory()
volume = UsdVol.Volume.Define(stage, "/Volume")
UsdVol.OpenVDBAsset.Define(stage, "/Field")
route = volume.GetPrim().CreateRelationship("route")
volume.GetPrim().CreateRelationship("field:density").SetTargets(["/Volume.route"])
for target in ("/Field", "/Missing"):
    route.SetTargets([target])
    paths = volume.GetFieldPaths()
    print(target, paths, stage.GetPrimAtPath(paths["density"]).IsValid())

route.SetTargets(["/Field"])
stage.GetPrimAtPath("/Field").SetActive(False)
paths = volume.GetFieldPaths()
print("inactive", paths, stage.GetPrimAtPath(paths["density"]).IsActive())

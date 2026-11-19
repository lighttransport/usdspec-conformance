"""Check whether PointInstancer produces a finite matrix for authored rotations."""
from math import isfinite

from pxr import Gf, Usd, UsdGeom

stage = Usd.Stage.CreateInMemory()
UsdGeom.Xform.Define(stage, "/Prototype")
instancer = UsdGeom.PointInstancer.Define(stage, "/Instancer")
instancer.CreatePrototypesRel().SetTargets(["/Prototype"])
instancer.CreateProtoIndicesAttr([0])
instancer.CreatePositionsAttr([(2, 0, 0)])
orientation = instancer.CreateOrientationsfAttr()

for label, value in (
    ("unit", Gf.Quatf(1, 0, 0, 0)),
    ("NaN", Gf.Quatf(float("nan"), 1, 0, 0)),
    ("infinite", Gf.Quatf(1, float("inf"), 0, 0)),
):
    orientation.Set([value])
    matrices = instancer.ComputeInstanceTransformsAtTime(0, 0)
    print(label, len(matrices), [all(map(isfinite, row)) for row in matrices[0]])

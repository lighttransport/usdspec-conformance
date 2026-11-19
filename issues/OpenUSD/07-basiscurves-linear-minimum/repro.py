"""Print stock USD segment counts for short linear curves."""
from pxr import Usd, UsdGeom

stage = Usd.Stage.CreateInMemory()
curves = UsdGeom.BasisCurves.Define(stage, "/Curves")
curves.CreateTypeAttr("linear")
print("OpenUSD", Usd.GetVersion())
for wrap in ("nonperiodic", "periodic", "pinned"):
    curves.CreateWrapAttr().Set(wrap)
    for count in (1, 2, 3, 4):
        curves.CreateCurveVertexCountsAttr().Set([count])
        print(wrap, count, list(curves.ComputeSegmentCounts(Usd.TimeCode.Default())))

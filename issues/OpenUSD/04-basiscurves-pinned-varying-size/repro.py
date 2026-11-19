"""Print varying-data sizes for short pinned cubic curves."""
from pxr import Usd, UsdGeom

stage = Usd.Stage.CreateInMemory()
curves = UsdGeom.BasisCurves.Define(stage, "/Curves")
curves.GetTypeAttr().Set("cubic")
curves.GetWrapAttr().Set("pinned")
print("OpenUSD", Usd.GetVersion())
for basis in ("bspline", "catmullRom"):
    curves.GetBasisAttr().Set(basis)
    for count in (2, 3, 4, 5):
        curves.GetCurveVertexCountsAttr().Set([count])
        size = curves.ComputeVaryingDataSize(Usd.TimeCode.Default())
        print(basis, count, size)

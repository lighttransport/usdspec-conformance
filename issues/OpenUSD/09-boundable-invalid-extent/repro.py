"""Show which malformed sampled extents OpenUSD passes to callers."""
from pxr import Usd, UsdGeom

stage = Usd.Stage.CreateInMemory()
cube = UsdGeom.Cube.Define(stage, "/Cube")
samples = [
    [(0, 0, 0)],
    [(0, 3, 0), (2, 2, 2)],
    [(0, 0, 0), (float("nan"), 2, 2)],
]
for time, bounds in enumerate(samples):
    cube.GetExtentAttr().Set(bounds, time)
    print(time, cube.ComputeExtent(time))

#!/usr/bin/env python3
"""Points with constant-interpolated widths get no computed extent."""
from pxr import Usd, UsdGeom

stage = Usd.Stage.CreateInMemory()
for name, widths, interp in (("Vertex", [0.5, 1.0], UsdGeom.Tokens.vertex),
                             ("Constant", [1.0], UsdGeom.Tokens.constant)):
    points = UsdGeom.Points.Define(stage, f"/{name}")
    points.CreatePointsAttr([(0, 0, 0), (2, 0, 0)])
    points.CreateWidthsAttr(widths)
    points.SetWidthsInterpolation(interp)
    print(name, interp, UsdGeom.Boundable.ComputeExtentFromPlugins(points, 0))
# Expected (widths sized by interpolation, as the schema documents):
#   Vertex vertex  [(-0.25, -0.5, -0.5), (2.5, 0.5, 0.5)]
#   Constant constant [(-0.5, -0.5, -0.5), (2.5, 0.5, 0.5)]
# Observed in OpenUSD 26.11: Constant returns None.

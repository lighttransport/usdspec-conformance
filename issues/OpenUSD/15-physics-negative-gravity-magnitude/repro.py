#!/usr/bin/env python3
"""A negative authored gravityMagnitude is not replaced by earth gravity."""
import warnings
from pxr import Usd, UsdPhysics

stage = Usd.Stage.CreateInMemory()
stage.GetRootLayer().ImportFromString('''#usda 1.0
(
    metersPerUnit = 0.01
)
def PhysicsScene "S" {
    float physics:gravityMagnitude = -1
}
''')
with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    result = UsdPhysics.LoadUsdPhysicsFromRange(stage, ["/"])
_, descs = result[UsdPhysics.ObjectType.Scene]
print("gravityMagnitude:", descs[0].gravityMagnitude, "(schema doc implies 981)")

#!/usr/bin/env python3
"""An unauthored invertFilteredGroups is reported from uninitialized memory."""
import warnings
from pxr import Usd, UsdPhysics

stage = Usd.Stage.CreateInMemory()
stage.GetRootLayer().ImportFromString('''#usda 1.0
def PhysicsCollisionGroup "Plain" {
}
''')
with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    result = UsdPhysics.LoadUsdPhysicsFromRange(stage, ["/"])
_, descs = result[UsdPhysics.ObjectType.CollisionGroup]
print("invertFilteredGroups:", descs[0].invertFilteredGroups, "(expected False)")

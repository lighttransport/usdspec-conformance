"""Show the sphere radii OpenUSD imports from indexed Points widths."""
from pxr import Sdf, Usd, UsdGeom, UsdPhysics, UsdValidation

stage = Usd.Stage.CreateInMemory()
points = UsdGeom.Points.Define(stage, "/Points")
points.CreatePointsAttr([(0, 0, 0), (1, 0, 0)])
points.CreateWidthsAttr([99])
UsdPhysics.CollisionAPI.Apply(points.GetPrim())
widths = UsdGeom.PrimvarsAPI(points).CreatePrimvar(
    "widths", Sdf.ValueTypeNames.FloatArray, "vertex", 2
)
widths.Set([2, 4, -1, 8])

checker = UsdValidation.ValidationRegistry().GetOrLoadValidatorByName(
    "usdPhysicsValidators:ColliderChecker"
)

for indices in ([0], [0, 0], [1]):
    widths.SetIndices(indices)
    result = UsdPhysics.LoadUsdPhysicsFromRange(stage, [Sdf.Path("/")])
    _, descriptors = result[UsdPhysics.ObjectType.SpherePointsShape]
    print(indices, [[sphere.radius for sphere in desc.spherePoints] for desc in descriptors])
    print("validator:", [error.GetName() for error in checker.Validate(points.GetPrim())])

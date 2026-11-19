import UsdSpec.Domains.Validation
import UsdSpec.Domains.SkeletonValidation
import UsdSpec.Domains.VolumeValidation
import UsdSpec.ValueResolution.Metadata
import UsdSpec.ValueResolution.TimeSamples
import Lean.Data.Json

namespace Gen.DomainComposedValidation

open Lean UsdSpec.Domains UsdSpec.Domains.VolumeValidation
open UsdSpec.Domains.SkeletonValidation UsdSpec.ValueResolution.Metadata

structure Probe where
  id : String
  kind : String
  rule : String
  before : String
  after : String
  common : String := ""
  siblings : String := ""
  metadata : String := ""
  checks : Bool → Nat × Nat
  diagnosticPrim : String := "/Subject"
  parentNames : List String := []
  materialXPorts : List (String × Bool × String × String) := []
  errorTimes : Option (Bool → List Nat) := none
  composedOnly : Bool := false
  flattenedChecks : Option (Bool → Nat × Nat) := none

def cases : List Probe := [
  { id := "skinning-inherited-influences", kind := "SkelRoot", rule := "geom.skel.skinning.index"
    before := "int[] primvars:skel:jointIndices = [0] (\nelementSize = 1\ninterpolation = \"constant\"\n)"
    after := "int[] primvars:skel:jointIndices = [1] (\nelementSize = 1\ninterpolation = \"constant\"\n)"
    metadata := " (prepend apiSchemas = [\"SkelBindingAPI\"])"
    diagnosticPrim := "/Subject/Geometry"
    common := "uniform token[] skel:joints = [\"root\"]\ndef Mesh \"Geometry\" (prepend apiSchemas = [\"SkelBindingAPI\"]) {\nfloat[] primvars:skel:jointWeights = [1] (\nelementSize = 1\ninterpolation = \"constant\"\n)\n}"
    checks := fun bad =>
      let order := inheritedInfluence none (some 1)
      let indices := inheritedInfluence none (some [if bad then 1 else 0])
      (influenceIndexErrors order none (indices.getD []), 0) },
  { id := "skinning-selected-joint-indices", kind := "Mesh", rule := "geom.skel.skinning.index"
    before := "int[] primvars:skel:jointIndices:indices = [0,0]"
    after := "int[] primvars:skel:jointIndices:indices = [1,1]"
    common := "point3f[] points = [(0,0,0),(1,0,0)]\nuniform token[] skel:joints = [\"root\"]\nint[] primvars:skel:jointIndices = [0,1] (\nelementSize = 1\ninterpolation = \"vertex\"\n)\nfloat[] primvars:skel:jointWeights = [1,1] (\nelementSize = 1\ninterpolation = \"vertex\"\n)"
    checks := fun bad => (influenceIndexErrors (some 1) none
      (selectedInfluenceRows [0, 1] (if bad then [1,1] else [0,0])), 0) },
  { id := "skinning-selected-joint-weights", kind := "Mesh", rule := "geom.skel.skinning.weight"
    before := "int[] primvars:skel:jointWeights:indices = [0,0]"
    after := "int[] primvars:skel:jointWeights:indices = [1,1]"
    common := "point3f[] points = [(0,0,0),(1,0,0)]\nint[] primvars:skel:jointIndices = [0,0] (\nelementSize = 1\ninterpolation = \"vertex\"\n)\nfloat[] primvars:skel:jointWeights = [1,inf] (\nelementSize = 1\ninterpolation = \"vertex\"\n)"
    checks := fun bad =>
      let diagnoses := (selectedInfluenceRows [[some (1 : Rat)], [none]]
        (if bad then [1,1] else [0,0])).map influenceWeightGroup
      ((diagnoses.filter (· == .error)).length, (diagnoses.filter (· == .warning)).length) },
  { id := "skinning-vertex-group-count", kind := "Mesh", rule := "geom.skel.skinning.size"
    before := "point3f[] points = [(0,0,0),(1,0,0)]"
    after := "point3f[] points = [(0,0,0)]"
    metadata := " (prepend apiSchemas = [\"SkelBindingAPI\"])"
    common := "int[] primvars:skel:jointIndices = [0,0] (\nelementSize = 1\ninterpolation = \"vertex\"\n)\nfloat[] primvars:skel:jointWeights = [1,1] (\nelementSize = 1\ninterpolation = \"vertex\"\n)"
    checks := fun bad => (if influenceGroupCountValid "vertex" (some (if bad then 1 else 2)) 2 2
      then 0 else 1, 0) },
  { id := "skinning-inherited-skeleton", kind := "SkelRoot", rule := "geom.skel.skinning.index"
    before := "rel skel:skeleton = </LongRig>"
    after := "rel skel:skeleton = </ShortRig>"
    metadata := " (prepend apiSchemas = [\"SkelBindingAPI\"])"
    diagnosticPrim := "/Subject/Geometry"
    common := "def Mesh \"Geometry\" {\nint[] primvars:skel:jointIndices = [1] (\nelementSize = 1\ninterpolation = \"constant\"\n)\nfloat[] primvars:skel:jointWeights = [1] (\nelementSize = 1\ninterpolation = \"constant\"\n)\n}"
    siblings := "def Skeleton \"ShortRig\" {\nuniform token[] joints = [\"root\"]\n}\ndef Skeleton \"LongRig\" {\nuniform token[] joints = [\"root\", \"root/child\"]\n}\n"
    checks := fun bad => (influenceIndexErrors none (some (if bad then 1 else 2)) [1], 0) },
  { id := "skinning-local-joint-order", kind := "Mesh", rule := "geom.skel.skinning.index"
    before := "uniform token[] skel:joints = [\"root/child\", \"root\"]"
    after := "uniform token[] skel:joints = [\"root\"]"
    metadata := " (prepend apiSchemas = [\"SkelBindingAPI\"])"
    common := "rel skel:skeleton = </Rig>\nint[] primvars:skel:jointIndices = [1] (\nelementSize = 1\ninterpolation = \"constant\"\n)\nfloat[] primvars:skel:jointWeights = [1] (\nelementSize = 1\ninterpolation = \"constant\"\n)"
    siblings := "def Skeleton \"Rig\" {\nuniform token[] joints = [\"root\", \"root/child\"]\n}\n"
    checks := fun bad => (influenceIndexErrors (some (if bad then 1 else 2)) (some 2) [1], 0) },
  { id := "mesh-normal-primvar-precedence", kind := "Mesh", rule := "geom.mesh.normals"
    common := "uniform token subdivisionScheme = \"none\"\npoint3f[] points = [(0,0,0),(1,0,0),(0,1,0)]\nint[] faceVertexCounts = [3]\nint[] faceVertexIndices = [0,1,2]\nnormal3f[] normals = [(0,1,0)]"
    before := "normal3f[] primvars:normals = [(0,0,1)]"
    after := "normal3f[] primvars:normals = [(0,0,1),(0,0,1),(0,0,1)]"
    checks := fun bad =>
      (if meshNormalPrimvarValid (meshNormalCount (some "constant") (some 3) (some 1) (some 3))
          (if bad then 3 else 1) 1 none then 0 else 1, 0) },
  { id := "mesh-normal-primvar-empty-selectors", kind := "Mesh", rule := "geom.mesh.normals"
    common := "uniform token subdivisionScheme = \"none\"\npoint3f[] points = [(0,0,0),(1,0,0),(0,1,0)]\nint[] faceVertexCounts = [3]\nint[] faceVertexIndices = [0,1,2]\nnormal3f[] primvars:normals = [(1,0,0),(1,0,0),(1,0,0)] (interpolation = \"vertex\")"
    before := "int[] primvars:normals:indices = [0,1,2]"
    after := "int[] primvars:normals:indices = []"
    checks := fun bad =>
      (if meshNormalPrimvarValid (meshNormalCount (some "vertex") (some 3) (some 1) (some 3))
          3 1 (some (if bad then [] else [0,1,2])) then 0 else 1, 0) },
  { id := "mesh-normal-primvar-indexed", kind := "Mesh", rule := "geom.mesh.normals"
    common := "uniform token subdivisionScheme = \"none\"\npoint3f[] points = [(0,0,0),(1,0,0),(1,1,0),(0,1,0)]\nint[] faceVertexCounts = [3,3]\nint[] faceVertexIndices = [0,1,2,0,2,3]\nnormal3f[] primvars:normals = [(0,0,1),(0,0,1)] (interpolation = \"faceVarying\"\nelementSize = 2\n)"
    before := "int[] primvars:normals:indices = [0,0,0]"
    after := "int[] primvars:normals:indices = [0,0,1]"
    checks := fun bad =>
      (if meshNormalPrimvarValid (meshNormalCount (some "faceVarying") (some 4) (some 2) (some 6))
          2 2 (some [0,0,if bad then 1 else 0]) then 0 else 1, 0) },
  { id := "mesh-normal-face-varying", kind := "Mesh", rule := "geom.mesh.normals"
    common := "uniform token subdivisionScheme = \"none\"\npoint3f[] points = [(0,0,0),(1,0,0),(1,1,0),(0,1,0)]\nint[] faceVertexCounts = [3,3]\nint[] faceVertexIndices = [0,1,2,0,2,3]"
    before := "normal3f[] normals = [(0,0,1),(0,0,1),(0,0,1),(0,0,1),(0,0,1),(0,0,1)] (interpolation = \"faceVarying\")"
    after := "normal3f[] normals = [(0,0,1),(0,0,1),(0,0,1),(0,0,1)] (interpolation = \"faceVarying\")"
    checks := fun bad =>
      (if meshNormalCount (some "faceVarying") (some 4) (some 2) (some 6)
          = some (if bad then 4 else 6) then 0 else 1, 0) },
  { id := "mesh-normal-vertex-sampled", kind := "Mesh", rule := "geom.mesh.normals"
    common := "uniform token subdivisionScheme = \"none\"\npoint3f[] points = [(0,0,0),(1,0,0),(0,1,0)]\nint[] faceVertexCounts = [3]\nint[] faceVertexIndices = [0,1,2]"
    before := "normal3f[] normals.timeSamples = {1: [(0,0,1),(0,0,1),(0,0,1)], 2: [(0,0,1),(0,0,1),(0,0,1)]}"
    after := "normal3f[] normals.timeSamples = {1: [(0,0,1),(0,0,1),(0,0,1)], 2: [(0,0,1)]}"
    checks := fun _ => (0, 0)
    errorTimes := some fun bad =>
      let expected := meshNormalCount none (some 3) (some 1) (some 3)
      ([(1, 3), (2, if bad then 1 else 3)] : List (Nat × Nat)).filterMap fun (t, n) =>
        if some n == expected then none else some t },
  { id := "mesh-normal-uniform", kind := "Mesh", rule := "geom.mesh.normals"
    common := "uniform token subdivisionScheme = \"none\"\npoint3f[] points = [(0,0,0),(1,0,0),(1,1,0),(0,1,0)]\nint[] faceVertexCounts = [3,3]\nint[] faceVertexIndices = [0,1,2,0,2,3]"
    before := "normal3f[] normals = [(0,0,1),(0,0,1)] (interpolation = \"uniform\")"
    after := "normal3f[] normals = [(0,0,1)] (interpolation = \"uniform\")"
    checks := fun bad =>
      (if meshNormalCount (some "uniform") (some 4) (some 2) (some 6)
          = some (if bad then 1 else 2) then 0 else 1, 0) },
  { id := "geom-extent-sampled-order", kind := "Cube", rule := "geom.gprim.extent"
    before := "float3[] extent.timeSamples = {0: [(-1,-1,-1), (1,1,1)], 1: [(0,0,0), (2,2,2)]}"
    after := "float3[] extent.timeSamples = {0: [(-1,-1,-1), (1,1,1)], 1: [(0,3,0), (2,2,2)]}"
    checks := fun bad => (extentErrors (some [(.finite 0, .finite (if bad then 3 else 0), .finite 0),
      (.finite 2, .finite 2, .finite 2)]), 0) },
  { id := "geom-extent-sampled-value", kind := "Cube", rule := "geom.gprim.extent"
    before := "float3[] extent.timeSamples = {0: None, 1: [(0,0,0), (2,2,2)], 2: [(0,0,0), (2,2,2)]}"
    after := "float3[] extent.timeSamples = {0: None, 1: [(0,0,0)], 2: [(0,0,0), (nan,2,2)]}"
    checks := fun bad =>
      let lower : ExtentPoint := (.finite 0, .finite 0, .finite 0)
      let upper : ExtentPoint := (.finite 2, .finite 2, .finite 2)
      (extentErrors none + extentErrors (some (if bad then [lower] else [lower, upper])) +
        extentErrors (some [lower, if bad then (.invalid, .finite 2, .finite 2) else upper]), 0) },
  { id := "camera-focal-length-samples", kind := "Camera", rule := "geom.camera.optics"
    before := "float focalLength.timeSamples = {0: 35, 1: 50}"
    after := "float focalLength.timeSamples = {0: 35, 1: 0}"
    checks := fun bad => (if cameraOpticValid false (.finite (if bad then 0 else 50))
      then 0 else 1, 0) },
  { id := "camera-clipping-range-samples", kind := "Camera", rule := "geom.camera.range"
    before := "float2 clippingRange.timeSamples = {0: (0,10), 1: (1,10)}"
    after := "float2 clippingRange.timeSamples = {0: (0,10), 1: (10,1)}"
    common := "float2 clippingRange = (0,10)"
    checks := fun bad => (cameraClippingErrors [some (.finite 0,.finite 10),
      some (.finite 0,.finite 10), some (if bad then (.finite 10,.finite 1)
        else (.finite 1,.finite 10))], 0) },
  { id := "camera-projection-samples", kind := "Camera", rule := "geom.camera.tokens"
    before := "token projection.timeSamples = {0: \"perspective\", 1: \"orthographic\"}"
    after := "token projection.timeSamples = {0: \"perspective\", 1: \"fisheye\"}"
    checks := fun bad => (if cameraTokensValid "projection"
      [.token "perspective", .token (if bad then "fisheye" else "orthographic")]
      then 0 else 1, 0) },
  { id := "camera-shutter-sampled-order", kind := "Camera", rule := "geom.camera.shutter"
    before := "double shutter:close.timeSamples = {1: 0, 2: 2}"
    after := "double shutter:close.timeSamples = {1: 0, 2: 0}"
    common := "double shutter:open.timeSamples = {1: -1, 2: 1}"
    checks := fun _ => (0, 0)
    errorTimes := some fun bad =>
      let samples : List (Nat × Rat × Rat) := [(1, -1, 0), (2, 1, if bad then 0 else 2)]
      samples.filterMap fun (time, opens, closes) =>
        if cameraShutterValid (.finite opens) (.finite closes) then none else some time },
  { id := "camera-shutter-order", kind := "Camera", rule := "geom.camera.shutter"
    before := "double shutter:close = 1"
    after := "double shutter:close = -1"
    common := "double shutter:open = 0"
    checks := fun bad => (if cameraShutterValid (.finite 0) (.finite (if bad then -1 else 1))
      then 0 else 1, 0) },
  { id := "hermite-tangent-count", kind := "HermiteCurves", rule := "geom.curves.topology"
    before := "vector3f[] tangents = [(1,0,0),(1,0,0)]"
    after := "vector3f[] tangents = [(1,0,0)]"
    common := "point3f[] points = [(0,0,0),(1,0,0)]"
    checks := fun bad => (if hermiteTangentCountValid 2 (if bad then 1 else 2)
      then 0 else 1, 0) },
  { id := "hermite-tangent-count-sampled", kind := "HermiteCurves", rule := "geom.curves.topology"
    before := "vector3f[] tangents.timeSamples = {1: [(1,0,0)], 2: [(1,0,0),(1,0,0)]}"
    after := "vector3f[] tangents.timeSamples = {1: [(1,0,0)], 2: [(1,0,0)]}"
    common := "point3f[] points.timeSamples = {1: [(0,0,0)], 2: [(0,0,0),(1,0,0)]}"
    checks := fun _ => (0, 0)
    errorTimes := some fun bad =>
      if hermiteTangentCountValid 2 (if bad then 1 else 2) then [] else [2] },
  { id := "nurbs-curves-sampled-knot-range", kind := "NurbsCurves", rule := "geom.nurbsCurves.topology"
    before := "double2[] ranges.timeSamples = {1: [(0,1)], 2: [(2,3)]}"
    after := "double2[] ranges.timeSamples = {1: [(0,1)], 2: [(0,1)]}"
    common := "int[] curveVertexCounts = [2]\nint[] order = [2]\ndouble[] knots.timeSamples = {1: [0,0,1,1], 2: [2,2,3,3]}"
    checks := fun _ => (0, 0)
    errorTimes := some fun bad =>
      let frames : List (Nat × (Rat × Rat) × Rat × Rat) :=
        [(1, (0,1), 0, 1), (2, (2,3), if bad then 0 else 2, if bad then 1 else 3)]
      frames.filterMap fun (time, bounds, lo, hi) =>
        if nurbsRangeValid (some bounds) (.finite lo) (.finite hi) then none else some time },
  { id := "nurbs-curves-batched-knots", kind := "NurbsCurves", rule := "geom.nurbsCurves.topology"
    before := "double[] knots = [0,0,1,1,0,0,0,1,1,1]"
    after := "double[] knots = [0,0,1,1,0,0,1,0,1,1]"
    common := "int[] curveVertexCounts = [2,3]\nint[] order = [2,3]"
    checks := fun bad => (nurbsTrimKnotErrors
      [[0,0,1,1], if bad then [0,0,1,0,1,1] else [0,0,0,1,1,1]], 0) },
  { id := "nurbs-curves-batched-range", kind := "NurbsCurves", rule := "geom.nurbsCurves.topology"
    before := "double2[] ranges = [(0,1),(2,3)]"
    after := "double2[] ranges = [(0,1),(1,3)]"
    common := "int[] curveVertexCounts = [2,2]\nint[] order = [2,2]\ndouble[] knots = [0,0,1,1,2,2,3,3]"
    checks := fun bad => (if nurbsRangeValid (some (2,3))
      (.finite (if bad then 1 else 2)) (.finite 3) then 0 else 1, 0) },
  { id := "nurbs-trim-unclamped-endpoints", kind := "NurbsPatch", rule := "geom.nurbsPatch.trimClosure"
    before := "double3[] trimCurve:points = [(0,0,1),(2,0,2),(4,0,1),(2,0,1),(2,0,3)]"
    after := "double3[] trimCurve:points = [(0,0,1),(2,0,2),(4,0,1),(2,0,1),(0,0,1)]"
    common := "int[] trimCurve:counts = [2]\nint[] trimCurve:orders = [3,2]\nint[] trimCurve:vertexCounts = [3,2]\ndouble[] trimCurve:knots = [0,1,2,3,4,5,0,0,1,1]\ndouble2[] trimCurve:ranges = [(2,3),(0,1)]"
    checks := fun bad => (0, trimLoopJoinWarnings
      [(uniformQuadraticEndpoint (0,0,1) (2,0,2), uniformQuadraticEndpoint (2,0,2) (4,0,1)),
       ((2,0), if bad then (0,0) else (2/3,0))]) },
  { id := "nurbs-trim-interior-endpoints", kind := "NurbsPatch", rule := "geom.nurbsPatch.trimClosure"
    before := "double3[] trimCurve:points = [(0,0,1),(1,0,1),(2,0,1),(1.5,0,1),(0.5,0,1)]"
    after := "double3[] trimCurve:points = [(0,0,1),(1,0,1),(2,0,1),(1.5,0,1),(0,0,1)]"
    common := "int[] trimCurve:counts = [2]\nint[] trimCurve:orders = [3,2]\nint[] trimCurve:vertexCounts = [3,2]\ndouble[] trimCurve:knots = [0,0,0,1,1,1,0,0,1,1]\ndouble2[] trimCurve:ranges = [(0.25,0.75),(0,1)]"
    checks := fun bad => (0, trimLoopJoinWarnings
      [((quadraticTrimCoordinate 0 1 2 (1/4),0),(quadraticTrimCoordinate 0 1 2 (3/4),0)),
       ((3/2,0), if bad then (0,0) else (1/2,0))]) },
  { id := "nurbs-trim-loop-closure", kind := "NurbsPatch", rule := "geom.nurbsPatch.trimClosure"
    before := "double3[] trimCurve:points = [(0,0,1),(1,0,1),(2,0,2),(0,0,1)]"
    after := "double3[] trimCurve:points = [(0,0,1),(1,0,1),(2,0,2),(1,1,1)]"
    common := "int[] trimCurve:counts = [2]\nint[] trimCurve:orders = [2,2]\nint[] trimCurve:vertexCounts = [2,2]\ndouble[] trimCurve:knots = [0,0,1,1,0,0,1,1]\ndouble2[] trimCurve:ranges = [(0,1),(0,1)]"
    checks := fun bad => (0, trimLoopJoinWarnings
      [((0,0),(1,0)), ((2/2,0), if bad then (1,1) else (0,0))]) },
  { id := "nurbs-trim-curve-order", kind := "NurbsPatch", rule := "geom.nurbsPatch.trimTopology"
    before := "int[] trimCurve:orders = [2,3]"
    after := "int[] trimCurve:orders = [3,2]"
    common := "int[] trimCurve:counts = [2]\nint[] trimCurve:vertexCounts = [2,3]\ndouble[] trimCurve:knots = [0,0,1,1,1,1,1,2,2,2]"
    checks := fun bad => (nurbsTrimOrderErrors [2,3] (if bad then [3,2] else [2,3]), 0) },
  { id := "nurbs-trim-knot-range", kind := "NurbsPatch", rule := "geom.nurbsPatch.trimTopology"
    before := "double2[] trimCurve:ranges = [(0,1),(3,4)]"
    after := "double2[] trimCurve:ranges = [(0,1),(0,1)]"
    common := "int[] trimCurve:counts = [2]\nint[] trimCurve:orders = [2,2]\nint[] trimCurve:vertexCounts = [2,2]\ndouble[] trimCurve:knots = [0,0,1,1,3,3,4,4]"
    checks := fun bad =>
      (if nurbsRangeValid (some (3,4)) (.finite (if bad then 0 else 3))
        (.finite (if bad then 1 else 4)) then 0 else 1, 0) },
  { id := "nurbs-trim-knot-segments", kind := "NurbsPatch", rule := "geom.nurbsPatch.trimTopology"
    before := "double[] trimCurve:knots = [0,0,1,1, 0,0,1,1]"
    after := "double[] trimCurve:knots = [0,0,1,1, 0,1,0,1]"
    common := "int[] trimCurve:counts = [2]\nint[] trimCurve:orders = [2,2]\nint[] trimCurve:vertexCounts = [2,2]"
    checks := fun bad => (nurbsTrimKnotErrors
      [[0,0,1,1], if bad then [0,1,0,1] else [0,0,1,1]], 0) },
  { id := "nurbs-trim-loop-count", kind := "NurbsPatch", rule := "geom.nurbsPatch.trimTopology"
    before := "int[] trimCurve:counts = [1]"
    after := "int[] trimCurve:counts = [2]"
    common := "int[] trimCurve:orders = [2]\nint[] trimCurve:vertexCounts = [2]\ndouble[] trimCurve:knots = [0,0,1,1]\ndouble2[] trimCurve:ranges = [(0,1)]\ndouble3[] trimCurve:points = [(0,0,1),(1,1,1)]"
    checks := fun bad => (nurbsTrimArrayErrors [if bad then 2 else 1] [2] [2] 1 4 2, 0) },
  { id := "nurbs-trim-knot-count", kind := "NurbsPatch", rule := "geom.nurbsPatch.trimTopology"
    before := "double[] trimCurve:knots = [0,0,1,1]"
    after := "double[] trimCurve:knots = [0,0,1]"
    common := "int[] trimCurve:counts = [1]\nint[] trimCurve:orders = [2]\nint[] trimCurve:vertexCounts = [2]\ndouble2[] trimCurve:ranges = [(0,1)]\ndouble3[] trimCurve:points = [(0,0,1),(1,1,1)]"
    checks := fun bad => (nurbsTrimArrayErrors [1] [2] [2] 1 (if bad then 3 else 4) 2, 0) },
  { id := "nurbs-patch-knot-range", kind := "NurbsPatch", rule := "geom.nurbsPatch.topology"
    before := "double[] vKnots = [0,1,4,5]"
    after := "double[] vKnots = [0,2,4,5]"
    common := "int vVertexCount = 2\nint vOrder = 2\ndouble2 vRange = (1,5)"
    checks := fun bad => (if nurbsRangeValid (some (if bad then 2 else 1, 5))
      (.finite 1) (.finite 5) then 0 else 1, 0) },
  { id := "nurbs-patch-control-grid", kind := "NurbsPatch", rule := "geom.nurbsPatch.topology"
    before := "int uVertexCount = 2"
    after := "int uVertexCount = 3"
    common := "int vVertexCount = 2\npoint3f[] points = [(0,0,0),(1,0,0),(0,1,0),(1,1,0)]"
    checks := fun bad => (if nurbsControlGridValid (if bad then 3 else 2) 2 4 then 0 else 1, 0) },
  { id := "mesh-index-count", kind := "Mesh", rule := "geom.mesh.topology.size"
    before := "int[] faceVertexCounts = [3]"
    after := "int[] faceVertexCounts = [4]"
    common := "int[] faceVertexIndices = [0,1,2]"
    checks := fun bad => (if meshIndexCountMatches (some [if bad then 4 else 3])
      (some [0,1,2]) then 0 else 1, 0) },
  { id := "subset-face-partition", kind := "Mesh", rule := "geom.subset.familyPartition"
    before := "def GeomSubset \"Group\" {\nuniform token familyName = \"groups\"\nint[] indices = [0,1]\n}"
    after := "def GeomSubset \"Group\" {\nuniform token familyName = \"groups\"\nint[] indices = [0,2]\n}"
    common := "uniform token subsetFamily:groups:familyType = \"partition\"\nint[] faceVertexCounts = [3,3]\nint[] faceVertexIndices = [0,1,2,0,2,3]\npoint3f[] points = [(0,0,0),(1,0,0),(1,1,0),(0,1,0)]"
    checks := fun bad =>
      (0, if subsetCoversDomain ([0,1] : List Nat) (if bad then [0,2] else [0,1]) then 0 else 1) },
  { id := "subset-edge-partition", kind := "Mesh", rule := "geom.subset.familyPartition"
    before := "def GeomSubset \"Group\" {\nuniform token familyName = \"groups\"\nuniform token elementType = \"edge\"\nint[] indices = [0,1,1,2,2,0]\n}"
    after := "def GeomSubset \"Group\" {\nuniform token familyName = \"groups\"\nuniform token elementType = \"edge\"\nint[] indices = [0,1,1,2,2,3]\n}"
    common := "uniform token subsetFamily:groups:familyType = \"partition\"\nint[] faceVertexCounts = [3]\nint[] faceVertexIndices = [0,1,2]\npoint3f[] points = [(0,0,0),(1,0,0),(0,1,0)]"
    checks := fun bad =>
      let domain : List (Nat × Nat) := [(0,1), (1,2), (0,2)]
      let members := [(0,1), (1,2), if bad then (2,3) else (0,2)]
      (0, if subsetCoversDomain domain members then 0 else 1) },
  { id := "points-varying-topology-widths", kind := "Points", rule := "geom.points.size"
    common := "point3f[] points = [(0,0,0),(1,0,0)]\npoint3f[] points.timeSamples = {1: [(0,0,0),(1,0,0)], 2: [(0,0,0),(1,0,0),(0,1,0)]}\nfloat[] widths = [1,2] (interpolation = \"varying\")"
    before := "float[] widths.timeSamples = {1: [1,2], 2: [1,2,3]}"
    after := "float[] widths.timeSamples = {1: [1,2], 2: [1,2]}"
    checks := fun _ => (0, 0)
    errorTimes := some fun bad =>
      ([(1, 2, 2), (2, 3, if bad then 2 else 3)] : List (Nat × Nat × Nat)).filterMap
        fun (t, points, widths) =>
          if pointsArraySizeValid .widths points widths (some "varying") then none else some t },
  { id := "points-constant-normals", kind := "Points", rule := "geom.points.size"
    before := "normal3f[] normals = [(0,0,1)] (interpolation = \"constant\")"
    after := "normal3f[] normals = [(0,0,1),(0,0,1)] (interpolation = \"constant\")"
    common := "point3f[] points = [(0,0,0),(1,0,0)]"
    checks := fun bad =>
      (if pointsArraySizeValid .normals 2 (if bad then 2 else 1) (some "constant")
        then 0 else 1, 0) },
  { id := "points-varying-widths", kind := "Points", rule := "geom.points.size"
    before := "float[] widths = [1,2] (interpolation = \"varying\")"
    after := "float[] widths = [1] (interpolation = \"varying\")"
    common := "point3f[] points = [(0,0,0),(1,0,0)]"
    checks := fun bad =>
      (if pointsArraySizeValid .widths 2 (if bad then 1 else 2) (some "varying")
        then 0 else 1, 0) },
  { id := "points-ids-count", kind := "Points", rule := "geom.points.size"
    before := "int64[] ids = [7,8]"
    after := "int64[] ids = [7]"
    common := "point3f[] points = [(0,0,0),(1,0,0)]"
    checks := fun bad => (if pointsArraySizeValid .ids 2 (if bad then 1 else 2) then 0 else 1, 0) },
  { id := "basis-curves-cubic-bezier-segments", kind := "BasisCurves", rule := "geom.curves.topology"
    before := "int[] curveVertexCounts = [4,7]"
    after := "int[] curveVertexCounts = [4,5]"
    checks := fun bad => (([4, if bad then 5 else 7].filter
      (!cubicBasisCountValid .bezier "nonperiodic" ·)).length, 0) },
  { id := "basis-curves-periodic-bezier-segments", kind := "BasisCurves", rule := "geom.curves.topology"
    before := "int[] curveVertexCounts = [3,6]"
    after := "int[] curveVertexCounts = [3,7]"
    common := "uniform token type = \"cubic\"\nuniform token basis = \"bezier\"\nuniform token wrap = \"periodic\""
    checks := fun bad => (([3, if bad then 7 else 6].filter
      (!cubicBasisCountValid .bezier "periodic" ·)).length, 0) },
  { id := "basis-curves-periodic-bezier-samples", kind := "BasisCurves", rule := "geom.curves.topology"
    before := "int[] curveVertexCounts.timeSamples = {1: [3], 2: [6]}"
    after := "int[] curveVertexCounts.timeSamples = {1: [3], 2: [7]}"
    common := "uniform token basis = \"bezier\"\nuniform token wrap = \"periodic\""
    checks := fun _ => (0, 0)
    errorTimes := some fun bad =>
      if cubicBasisCountValid .bezier "periodic" (if bad then 7 else 6) then [] else [2] },
  { id := "basis-curves-pinned-segments", kind := "BasisCurves", rule := "geom.curves.topology"
    before := "uniform token wrap = \"pinned\""
    after := "uniform token wrap = \"nonperiodic\""
    common := "uniform token basis = \"bspline\"\nint[] curveVertexCounts = [2]"
    checks := fun bad => (if cubicBasisCountValid .bspline
      (if bad then "nonperiodic" else "pinned") 2 then 0 else 1, 0) },
  { id := "basis-curves-varying-widths", kind := "BasisCurves", rule := "geom.curves.widths"
    before := "float[] widths = [1,1,1,1,1] (interpolation = \"varying\")"
    after := "float[] widths = [1,1] (interpolation = \"varying\")"
    common := "int[] curveVertexCounts = [4,7]"
    checks := fun bad =>
      (if curveVaryingWidths .bezier false [4,7] (if bad then 2 else 5) = .error
       then 1 else 0, 0) },
  { id := "instancer-blocked-required-sample", kind := "PointInstancer", rule := "geom.pointInstancer.requiredArray"
    before := "point3f[] positions.timeSamples = {2: [(0,0,0)], 4: [(1,0,0)], 6: [(2,0,0)]}"
    after := "point3f[] positions.timeSamples = {2: [(0,0,0)], 4: None, 6: [(2,0,0)]}"
    common := "rel prototypes = </Prototype>\nint[] protoIndices = [0]\npoint3f[] positions = [(99,0,0)]\nfloat3[] scales.timeSamples = {3: [(1,1,1)], 5: [(1,1,1)]}"
    siblings := "def Xform \"Prototype\" {}\n"
    checks := fun _ => (0, 0)
    errorTimes := some fun bad =>
      let samples : UsdSpec.ValueResolution.TimeSamples.Samples :=
        [(2, some 0), (4, if bad then none else some 1), (6, some 2)]
      ([2, 3, 4, 5, 6] : List Nat).flatMap fun (time : Nat) =>
        let position := (UsdSpec.ValueResolution.TimeSamples.eval .linear samples (time : Rat)).join
        List.replicate (pointInstancerRequiredArrayErrors [[position.map (fun _ => 1)], [some 1]]) time },
  { id := "instancer-required-array", kind := "PointInstancer", rule := "geom.pointInstancer.requiredArray"
    before := "point3f[] positions.timeSamples = {1: []}\nint[] protoIndices.timeSamples = {1: []}"
    after := "point3f[] positions = None\nint[] protoIndices = None"
    common := "rel prototypes = </Prototype>"
    siblings := "def Xform \"Prototype\" {}\n"
    composedOnly := true
    checks := fun bad =>
      let authored := if bad then none else some 0
      (pointInstancerRequiredArrayErrors [[authored], [authored]], 0) },
  { id := "instancer-unresolved-prototype", kind := "PointInstancer", rule := "geom.pointInstancer.prototypes"
    before := "rel prototypes = </Prototype>"
    after := "rel prototypes = </Missing>"
    common := "point3f[] positions = [(0,0,0)]\nint[] protoIndices = [0]"
    siblings := "def Xform \"Prototype\" {}\n"
    composedOnly := true
    checks := fun bad => (prototypeErrors (.relationship [!bad]), 0) },
  { id := "instancer-selected-orientation-cardinality", kind := "PointInstancer", rule := "geom.pointInstancer.arraySize"
    before := "quatf[] orientationsf.timeSamples = {1: [], 2: [(1,0,0,0)]}"
    after := "quatf[] orientationsf.timeSamples = {1: [(1,0,0,0),(1,0,0,0)], 2: [(1,0,0,0)]}"
    common := "rel prototypes = </Prototype>\npoint3f[] positions = [(0,0,0),(1,0,0)]\nint[] protoIndices = [0,0]\nquath[] orientations = [(1,0,0,0),(1,0,0,0)]"
    siblings := "def Xform \"Prototype\" {}\n"
    checks := fun bad =>
      let floatSamples := [some (if bad then 2 else 0), some 1]
      (if pointInstancerUsesFloatOrientations none floatSamples then
        (floatSamples.map (pointInstancerArrayErrors (some 2))).sum
       else pointInstancerArrayErrors (some 2) (some 2), 0) },
  { id := "instancer-half-orientation-norm", kind := "PointInstancer", rule := "geom.pointInstancer.orientation"
    before := "quath[] orientations = [(0.70703125,0.70703125,0,0)]"
    after := "quath[] orientations = [(0,0,0,0)]"
    common := "rel prototypes = </Prototype>\npoint3f[] positions = [(0,0,0)]\nint[] protoIndices = [0]"
    siblings := "def Xform \"Prototype\" {}\n"
    checks := fun bad =>
      (if pointInstancerQuaternionValid true
          (some (if bad then (0,0,0,0) else (181/256,181/256,0,0))) then 0 else 1, 0) },
  { id := "instancer-float-orientation-samples", kind := "PointInstancer", rule := "geom.pointInstancer.orientation"
    before := "quatf[] orientationsf.timeSamples = {1: [(1,0,0,0)], 2: [(0,0,0,1)]}"
    after := "quatf[] orientationsf.timeSamples = {1: [(2,0,0,0)], 2: [(nan,0,0,1)]}"
    common := "rel prototypes = </Prototype>\npoint3f[] positions = [(0,0,0)]\nint[] protoIndices = [0]"
    siblings := "def Xform \"Prototype\" {}\n"
    checks := fun bad =>
      let lanes : List (Option (Rat × Rat × Rat × Rat)) :=
        [some (if bad then (2,0,0,0) else (1,0,0,0)), if bad then none else some (0,0,0,1)]
      ((lanes.filter (!pointInstancerQuaternionValid false ·)).length, 0) },
  { id := "instancer-forwarding-prototype", kind := "PointInstancer", rule := "geom.pointInstancer.prototypes"
    before := "rel prototypes = </Prototype>"
    after := "rel prototypes = </Subject.route>"
    common := "rel route = </Prototype>\npoint3f[] positions = [(0,0,0)]\nint[] protoIndices = [0]"
    siblings := "def Xform \"Prototype\" {}\n"
    checks := fun bad => (prototypeErrors (.relationship [!bad]), 0) },
  { id := "instancer-prototype-index", kind := "PointInstancer", rule := "geom.pointInstancer.indices"
    before := "rel prototypes = [</First>, </Second>]"
    after := "rel prototypes = </First>"
    common := "point3f[] positions = [(0,0,0)]\nint[] protoIndices = [1]"
    siblings := "def Xform \"First\" {}\ndef Xform \"Second\" {}\n"
    checks := fun bad => (pointInstancerIndexErrors
      (.relationship (if bad then [true] else [true, true])) (some 1) (some [1]), 0) },
  { id := "instancer-varying-topology-scales", kind := "PointInstancer", rule := "geom.pointInstancer.arraySize"
    before := "float3[] scales.timeSamples = {1: [(1,1,1)], 2: [(1,1,1),(2,2,2)]}"
    after := "float3[] scales.timeSamples = {1: [(1,1,1)], 2: [(1,1,1)]}"
    common := "rel prototypes = </Prototype>\npoint3f[] positions = [(0,0,0)]\npoint3f[] positions.timeSamples = {1: [(0,0,0)], 2: [(0,0,0),(1,0,0)]}\nint[] protoIndices = [0]\nint[] protoIndices.timeSamples = {1: [0], 2: [0,0]}\nfloat3[] scales = [(1,1,1)]"
    siblings := "def Xform \"Prototype\" {}\n"
    checks := fun _ => (0, 0)
    errorTimes := some fun bad =>
      ([(1, 1, 1), (2, 2, if bad then 1 else 2)] : List (Nat × Nat × Nat)).flatMap
        fun (t, positions, scales) =>
          List.replicate (pointInstancerArrayErrors (some positions) (some scales)) t },
  { id := "instancer-empty-frame", kind := "PointInstancer", rule := "geom.pointInstancer.indices"
    before := "point3f[] positions.timeSamples = {1: [(0,0,0)], 2: []}"
    after := "point3f[] positions.timeSamples = {1: [(0,0,0)], 2: [(0,0,0)]}"
    common := "rel prototypes = </Prototype>\nint[] protoIndices.timeSamples = {1: [0], 2: []}"
    siblings := "def Xform \"Prototype\" {}\n"
    checks := fun _ => (0, 0)
    errorTimes := some fun bad =>
      let samples : List (Nat × Nat × List Int) := [(1, 1, [0]), (2, if bad then 1 else 0, [])]
      samples.flatMap fun (time, positions, indices) =>
        List.replicate (pointInstancerIndexErrors
          (.relationship [true]) (some positions) (some indices)) time },
  { id := "instancer-sampled-topology", kind := "PointInstancer", rule := "geom.pointInstancer.indices"
    before := "int[] protoIndices.timeSamples = {1: [0], 2: [1, 0]}"
    after := "int[] protoIndices.timeSamples = {1: [0], 2: [1]}"
    common := "rel prototypes = [</First>, </Second>]\npoint3f[] positions.timeSamples = {1: [(0,0,0)], 2: [(0,0,0),(1,0,0)]}"
    siblings := "def Xform \"First\" {}\ndef Xform \"Second\" {}\n"
    checks := fun _ => (0, 0)
    errorTimes := some fun bad =>
      let samples : List (Nat × Nat × List Int) :=
        [(1, 1, [0]), (2, 2, if bad then [1] else [1, 0])]
      samples.flatMap fun (time, positions, indices) =>
        List.replicate (pointInstancerIndexErrors
          (.relationship [true, true]) (some positions) (some indices)) time },
  { id := "skeleton-parent-order", kind := "Skeleton", rule := "geom.skel.skeleton.topology"
    before := "uniform token[] joints = [\"root\", \"root/child\"]"
    after := "uniform token[] joints = [\"root/child\", \"root\"]"
    checks := fun bad => skeletonTopology
      (if bad then ["root/child", "root"] else ["root", "root/child"]) },
  { id := "animation-translation-count", kind := "SkelAnimation", rule := "geom.skel.animation.transforms"
    before := "uniform token[] joints = [\"root\", \"root/child\"]"
    after := "uniform token[] joints = [\"root\"]"
    common := "float3[] translations.timeSamples = {0: [(0,0,0),(0,0,1)], 1: [(0,0,0),(1,0,0)]}"
    checks := fun bad => arrayCardinality (some (if bad then 1 else 2)) .absent [.array 2, .array 2] },
  { id := "blend-shape-inbetween-normals", kind := "BlendShape", rule := "geom.skel.blendShape.inbetween"
    before := "vector3f[] inbetweens:half:normalOffsets = [(0,0,0),(0,1,0)]"
    after := "vector3f[] inbetweens:half:normalOffsets = [(0,0,0)]"
    common := "uniform vector3f[] offsets = [(0,0,0),(1,0,0)]\nuniform point3f[] inbetweens:half = [(0,0,0),(1,0,0)] (weight = 0.5)"
    checks := fun bad => blendShapeInbetween (some 2) true (.array (if bad then 1 else 2)) },
  { id := "simulation-owner-target", kind := "Xform", rule := "physics.relationship.target"
    before := "rel physics:simulationOwner = [</SceneA>, </SceneB>]"
    after := "rel physics:simulationOwner = [</SceneA>, </Wrong>]"
    metadata := " (prepend apiSchemas = [\"PhysicsRigidBodyAPI\"])"
    siblings := "def PhysicsScene \"SceneA\" {}\ndef PhysicsScene \"SceneB\" {}\ndef Xform \"Wrong\" {}\n"
    checks := fun bad => (0, simulationOwnerTargetWarnings [some true, some (!bad)]) },
  { id := "collision-filter-group-target", kind := "PhysicsCollisionGroup"
    rule := "physics.collisionGroup.filteredGroups"
    before := "rel physics:filteredGroups = [</Other>]"
    after := "rel physics:filteredGroups = [</Other>, </Wrong>]"
    common := "string physics:mergeGroup = \"\"\nbool physics:invertFilteredGroups = true"
    siblings := "def PhysicsCollisionGroup \"Other\" {}\ndef Xform \"Wrong\" {}\n"
    checks := fun bad => (0, filteredGroupWarnings (if bad then [some true, some false] else [some true])) },
  { id := "points-collider-width-sample-only", kind := "Points", rule := "physics.collider.points"
    metadata := " (prepend apiSchemas = [\"PhysicsCollisionAPI\"])"
    common := "point3f[] points = [(0,0,0), (1,0,0)]\nfloat[] widths = [2,4]"
    before := "float[] primvars:widths = [2,4]"
    after := "float[] primvars:widths = None\nfloat[] primvars:widths.timeSamples = {1: [2,4]}"
    checks := fun bad =>
      (if pointsColliderWidthsValid 2 (if bad then [] else [.finite 2, .finite 4])
          none 1 then 0 else 1, 0) },
  { id := "points-collider-index-sample-only", kind := "Points", rule := "physics.collider.points"
    metadata := " (prepend apiSchemas = [\"PhysicsCollisionAPI\"])"
    common := "point3f[] points = [(0,0,0), (1,0,0)]\nfloat[] primvars:widths = [2,4]"
    before := "int[] primvars:widths:indices = [0,1]"
    after := "int[] primvars:widths:indices = None\nint[] primvars:widths:indices.timeSamples = {1: [1,0]}"
    checks := fun bad =>
      (if pointsColliderWidthsValid 2 [.finite 2, .finite 4]
          (some (if bad then [] else [0,1])) 1 then 0 else 1, 0) },
  { id := "points-collider-width-groups", kind := "Points", rule := "physics.collider.points"
    metadata := " (prepend apiSchemas = [\"PhysicsCollisionAPI\"])"
    common := "point3f[] points = [(0,0,0), (1,0,0)]\nfloat[] widths = [1]\nfloat[] primvars:widths = [2,4] (elementSize = 2)"
    before := "int[] primvars:widths:indices = [0]"
    after := "int[] primvars:widths:indices = [0,0]"
    checks := fun bad =>
      (if pointsColliderWidthsValid 2 [.finite 2, .finite 4]
          (some (if bad then [0,0] else [0])) 2 then 0 else 1, 0) },
  { id := "points-collider-selected-widths", kind := "Points", rule := "physics.collider.points"
    metadata := " (prepend apiSchemas = [\"PhysicsCollisionAPI\"])"
    common := "point3f[] points = [(0,0,0), (1,0,0)]\nfloat[] primvars:widths = [2,4,-1,8] (elementSize = 2)"
    before := "int[] primvars:widths:indices = [0]"
    after := "int[] primvars:widths:indices = [1]"
    checks := fun bad =>
      (if pointsColliderWidthsValid 2 [.finite 2, .finite 4, .finite (-1), .finite 8]
          (some [if bad then 1 else 0]) 2 then 0 else 1, 0) },
  { id := "joint-body-type", kind := "PhysicsRevoluteJoint", rule := "physics.joint.bodyTarget"
    before := "rel physics:body0 = </Body>"
    after := "rel physics:body0 = </Scene>"
    siblings := "def Xform \"Body\" {}\ndef PhysicsScene \"Scene\" {}\n"
    checks := fun bad => (jointBodyTargetErrors [if bad then .otherPrim else .xformable], 0) },
  { id := "joint-body-forwarded-property", kind := "PhysicsRevoluteJoint", rule := "physics.joint.bodyTarget"
    before := "rel physics:body0 = </Body>"
    after := "rel physics:body0 = </Links.body>"
    siblings := "def Xform \"Body\" (prepend apiSchemas = [\"PhysicsRigidBodyAPI\"]) {}\ndef Scope \"Links\" {\nrel body = </Body>\n}\n"
    checks := fun bad => (jointBodyTargetErrors [if bad then .forwardingProperty else .xformable], 0) },
  { id := "joint-body-unresolved", kind := "PhysicsRevoluteJoint", rule := "physics.joint.bodyTarget"
    before := "rel physics:body1 = </Body>"
    after := "rel physics:body1 = </Missing>"
    siblings := "def Xform \"Body\" {}\n"
    checks := fun bad => (jointBodyTargetErrors [if bad then .unresolved else .xformable], 0) },
  { id := "joint-body-count", kind := "PhysicsRevoluteJoint", rule := "physics.joint.bodyCount"
    before := "rel physics:body0 = None"
    after := "rel physics:body0 = [</Body>, </Other>]"
    siblings := "def Xform \"Body\" {}\ndef Xform \"Other\" {}\n"
    checks := fun bad => (if jointBodyCountValid (if bad then [.xformable, .xformable] else [])
      then 0 else 1, 0) },
  { id := "joint-bound", kind := "PhysicsRevoluteJoint", rule := "physics.joint.limit"
    before := "float physics:lowerLimit = -inf"
    after := "float physics:lowerLimit = inf"
    common := "float physics:upperLimit = inf"
    checks := fun bad => (jointLimitErrors (if bad then .positiveInfinity else .negativeInfinity)
      .positiveInfinity .absent .absent, 0) },
  { id := "materialx-synthetic-terminal-target-count", kind := "Material"
    rule := "shade.materialX.nodeReference"
    before := "rel mtlx:surface:source = </Graph>"
    after := "rel mtlx:surface:source = [</Graph>, </Second>]"
    siblings := "def NodeGraph \"Graph\" {}\ndef NodeGraph \"Second\" {}\n"
    parentNames := ["MaterialX", "Materials"]
    diagnosticPrim := "/MaterialX/Materials/Subject"
    checks := fun bad => (0, if materialXTerminalTargetCountWarning (if bad then 2 else 1)
      then 1 else 0) },
  { id := "materialx-synthetic-terminal-property-target", kind := "Material"
    rule := "shade.materialX.nodeReference"
    before := "rel mtlx:surface:source = </Graph>"
    after := "rel mtlx:surface:source = </Missing.outputs:out>"
    siblings := "def NodeGraph \"Graph\" {}\n"
    parentNames := ["MaterialX", "Materials"]
    diagnosticPrim := "/MaterialX/Materials/Subject"
    checks := fun bad => (materialXTerminalTargetErrors [if bad then .malformed else .nodeGraph], 0) },
  { id := "materialx-synthetic-terminal-target-type", kind := "Material"
    rule := "shade.materialX.nodeReference"
    before := "rel mtlx:volume:source = </Graph>"
    after := "rel mtlx:volume:source = </Wrong>"
    siblings := "def NodeGraph \"Graph\" {}\ndef Xform \"Wrong\" {}\n"
    parentNames := ["MaterialX", "Materials"]
    diagnosticPrim := "/MaterialX/Materials/Subject"
    checks := fun bad => (materialXTerminalTargetErrors [if bad then .otherPrim else .nodeGraph], 0) },
  { id := "materialx-synthetic-terminal-block", kind := "Material", rule := "shade.materialX.nodeReference"
    before := "rel mtlx:surface:source = </Graph>"
    after := "rel mtlx:surface:source = None"
    common := "rel mtlx:volume:source = None"
    siblings := "def NodeGraph \"Graph\" {}\n"
    parentNames := ["MaterialX", "Materials"]
    diagnosticPrim := "/MaterialX/Materials/Subject"
    checks := fun bad => (if materialXHasTerminalSource [if bad then 0 else 1, 0, 0]
      then 0 else 1, 0) },
  { id := "materialx-packaged-source-uri", kind := "Material", rule := "shade.materialX.sourceUri"
    before := "string config:mtlx:sourceUri = \"library.usdz[looks/surface.mtlx]\""
    after := "string config:mtlx:sourceUri = \"library.usdz[looks/surface.usda]\""
    metadata := " (prepend apiSchemas = [\"MaterialXConfigAPI\"])"
    checks := fun bad => (0, if materialXSourceWarning "library.usdz"
      (some (if bad then "looks/surface.usda" else "looks/surface.mtlx")) then 1 else 0) },
  { id := "materialx-nodedef-port-membership", kind := "Shader", rule := "shade.materialX.unknownPort"
    before := "uniform token info:id = \"ND_constant_color3\""
    after := "uniform token info:id = \"ND_standard_surface_surfaceshader\""
    common := "color3f inputs:value = (0,1,0)"
    materialXPorts := [("ND_constant_color3", false, "value", "color3f"),
      ("ND_standard_surface_surfaceshader", false, "value", "")]
    checks := fun bad => (0, materialXUnknownPortCount
      (if bad then ["inputs:base_color", "outputs:out"] else ["inputs:value", "outputs:out"])
      ["inputs:value"]) },
  { id := "materialx-nodedef-output-type", kind := "Shader", rule := "shade.shader.typeMismatch"
    before := "color3f outputs:out = (0,1,0)"
    after := "float outputs:out = 1"
    common := "uniform token info:id = \"ND_constant_color3\""
    materialXPorts := [("ND_constant_color3", false, "value", "color3f"),
      ("ND_constant_color3", true, "out", "color3f")]
    checks := fun bad => (0, if materialXConnectionWarning (some "color3f")
      (some (if bad then "float" else "color3f")) then 1 else 0) },
  { id := "materialx-connection-port-type", kind := "Shader", rule := "shade.materialX.connectionType"
    before := "color3f inputs:base_color.connect = </Color.outputs:out>"
    after := "color3f inputs:base_color.connect = </Scalar.outputs:out>"
    common := "uniform token info:id = \"ND_standard_surface_surfaceshader\""
    materialXPorts := [("ND_standard_surface_surfaceshader", false, "base_color", "color3f"),
      ("ND_standard_surface_surfaceshader", true, "out", "token")]
    siblings := "def Shader \"Color\" {\ncolor3f outputs:out\n}\ndef Shader \"Scalar\" {\nfloat outputs:out\n}\n"
    checks := fun bad => (0, if materialXConnectionWarning
      (some (if bad then "float" else "color3f")) (some "color3f") then 1 else 0) },
  { id := "materialx-version", kind := "Material", rule := "shade.materialX.version"
    before := "string config:mtlx:version = \"1.39\""
    after := "string config:mtlx:version = \"2.0\""
    metadata := " (prepend apiSchemas = [\"MaterialXConfigAPI\"])"
    checks := fun bad => (0, if materialXVersion (.string (if bad then "2.0" else "1.39"))
      = .warning then 1 else 0) },
  { id := "volume-field-index-samples", kind := "OpenVDBAsset", rule := "vol.fieldAsset.fieldIndex"
    before := "int fieldIndex.timeSamples = {0: 0, 1: 1}"
    after := "int fieldIndex.timeSamples = {0: 0, 1: -1}"
    common := "asset filePath = @frame.vdb@"
    checks := fun bad => (negativeFieldIndexCount [some 0, some (if bad then -1 else 1)], 0) },
  { id := "volume-untyped-composed-field", kind := "Volume", rule := "vol.volume.fieldTargetType"
    before := "rel field:density = </Field>"
    after := "rel field:density = </Untyped>"
    siblings := "def OpenVDBAsset \"Field\" {}\ndef \"Untyped\" {}\n"
    composedOnly := true
    checks := fun bad =>
      (0, if volumeFieldTargetType 1 (if bad then .other else .volumeField) = .warning
        then 1 else 0) },
  { id := "volume-inactive-field", kind := "Volume", rule := "vol.volume.fieldTargetMissing"
    before := "rel field:density = </Present>"
    after := "rel field:density = </Inactive>"
    siblings := "def OpenVDBAsset \"Present\" {}\ndef OpenVDBAsset \"Inactive\" (active = false) {}\n"
    composedOnly := true
    checks := fun bad =>
      (0, if volumeFieldTargetMissing 1 (!bad) = .warning then 1 else 0) },
  { id := "volume-unresolved-field", kind := "Volume", rule := "vol.volume.fieldTargetMissing"
    before := "rel route = </Field>"
    after := "rel route = </Missing>"
    common := "rel field:density = </Subject.route>"
    siblings := "def OpenVDBAsset \"Field\" {}\n"
    composedOnly := true
    checks := fun bad =>
      let paths := forwardedFieldPaths [[if bad then "/Missing" else "/Field"]]
      (0, if volumeFieldTargetMissing paths.length (!bad) = .warning then 1 else 0) },
  { id := "volume-blocked-field", kind := "Volume", rule := "vol.volume.fieldRel"
    before := "rel field:density = None"
    after := "rel field:density = </Subject.route>"
    common := "rel route = []"
    checks := fun bad =>
      (0, if volumeFieldRelationship (if bad then .targets 0 else .blocked)
        = .warning then 1 else 0)
    flattenedChecks := some fun _ =>
      (0, if volumeFieldRelationship (.targets 0) = .warning then 1 else 0) },
  { id := "volume-forwarded-shared-field", kind := "Volume", rule := "vol.volume.fieldTargetCount"
    before := "rel right = </First>"
    after := "rel right = </Second>"
    common := "rel field:density = [</Subject.left>, </Subject.right>]\nrel left = </First>"
    siblings := "def OpenVDBAsset \"First\" {}\ndef OpenVDBAsset \"Second\" {}\n"
    checks := fun bad =>
      let targets := forwardedFieldPaths [["/First"], [if bad then "/Second" else "/First"]]
      (0, if volumeFieldTargetCount targets.length = .warning then 1 else 0) },
  { id := "volume-forwarded-field-count", kind := "Volume", rule := "vol.volume.fieldTargetCount"
    before := "rel route = </Field>"
    after := "rel route = [</Field>, </Second>]"
    common := "rel field:density = </Subject.route>"
    siblings := "def OpenVDBAsset \"Field\" {}\ndef OpenVDBAsset \"Second\" {}\n"
    checks := fun bad =>
      let targets := forwardedFieldPaths [if bad then ["/Field", "/Second"] else ["/Field"]]
      (0, if volumeFieldTargetCount targets.length = .warning then 1 else 0) },
  { id := "volume-forwarded-attribute-target", kind := "Volume", rule := "vol.volume.fieldTargetType"
    before := "rel route = </Field>"
    after := "rel route = </Field.fieldName>"
    common := "rel field:density = </Subject.route>"
    siblings := "def OpenVDBAsset \"Field\" { token fieldName = \"density\" }\n"
    checks := fun bad =>
      let targets := forwardedFieldPaths [[if bad then "/Field.fieldName" else "/Field"]]
      (0, if volumeFieldTargetType targets.length (if bad then .nonPrimPath else .volumeField)
        = .warning then 1 else 0) },
  { id := "volume-forwarded-field-type", kind := "Volume", rule := "vol.volume.fieldTargetType"
    before := "rel route = </Field>"
    after := "rel route = </Other>"
    common := "rel field:density = </Subject.route>"
    siblings := "def OpenVDBAsset \"Field\" {}\ndef Xform \"Other\" {}\n"
    checks := fun bad =>
      let targets := forwardedFieldPaths [[if bad then "/Other" else "/Field"]]
      (0, if volumeFieldTargetType targets.length (if bad then .other else .volumeField)
        = .warning then 1 else 0) },
  { id := "volume-target-type", kind := "Volume", rule := "vol.volume.fieldTargetType"
    before := "rel field:density = </Field>"
    after := "rel field:density = </Other>"
    siblings := "def OpenVDBAsset \"Field\" {}\ndef Xform \"Other\" {}\n"
    checks := fun bad => (0, if volumeFieldTargetType 1 (if bad then .other else .volumeField)
      = .warning then 1 else 0) },
  { id := "volume-empty-file-samples", kind := "OpenVDBAsset", rule := "vol.fieldAsset.filePath"
    before := "asset filePath.timeSamples = {1: None, 2: @frame.vdb@}"
    after := "asset filePath.timeSamples = {1: None, 2: @@}"
    checks := fun bad =>
      let paths : List (Option String) := [none, some (if bad then "" else "frame.vdb")]
      let usable := paths.filter (fun path => path.any (!·.isEmpty))
      (0, if fieldAssetFilePath true none usable.length = .warning then 1 else 0) },
  { id := "volume-blocked-data-type-samples", kind := "OpenVDBAsset", rule := "vol.fieldAsset.dataType"
    before := "token fieldDataType.timeSamples = {1: None, 2: \"float\"}"
    after := "token fieldDataType.timeSamples = {1: None, 2: None}"
    common := "asset filePath = @frame.vdb@"
    checks := fun bad =>
      let samples := [TokenOpinion.unauthored, if bad then .unauthored else .token "float"]
      fieldAssetDataType "OpenVDBAsset" (samples.any (fun sample => sample != .unauthored))
        .unauthored samples },
  { id := "volume-openvdb-class-samples", kind := "OpenVDBAsset", rule := "vol.fieldAsset.fieldClass"
    before := "token fieldClass.timeSamples = {1: \"levelSet\", 2: \"fogVolume\"}"
    after := "token fieldClass.timeSamples = {1: \"levelSet\", 2: \"FloatGrid\"}"
    common := "asset filePath = @frame.vdb@\ntoken fieldDataType = \"float\""
    checks := fun bad =>
      (if tokenProperty "OpenVDBAsset" "fieldClass" .unauthored
        [.token "levelSet", .token (if bad then "FloatGrid" else "fogVolume")] = .error
       then 1 else 0, 0) },
  { id := "volume-field3d-vector-role-samples", kind := "Field3DAsset", rule := "vol.fieldAsset.vectorDataRoleHint"
    before := "token vectorDataRoleHint.timeSamples = {1: \"Vector\", 2: \"Color\"}"
    after := "token vectorDataRoleHint.timeSamples = {1: \"Vector\", 2: \"vector\"}"
    common := "asset filePath = @frame.f3d@\ntoken fieldDataType = \"float3\""
    checks := fun bad =>
      (if tokenProperty "Field3DAsset" "vectorDataRoleHint" .unauthored
        [.token "Vector", .token (if bad then "vector" else "Color")] = .error
       then 1 else 0, 0) },
  { id := "volume-field3d-type-samples", kind := "Field3DAsset", rule := "vol.fieldAsset.dataType"
    before := "token fieldDataType.timeSamples = {1: \"float\", 2: \"float3\"}"
    after := "token fieldDataType.timeSamples = {1: \"float\", 2: \"int3\"}"
    common := "asset filePath = @frame.f3d@"
    checks := fun bad =>
      fieldAssetDataType "Field3DAsset" true .unauthored
        [.token "float", .token (if bad then "int3" else "float3")] },
  { id := "volume-field-type-samples", kind := "OpenVDBAsset", rule := "vol.fieldAsset.dataType"
    before := "token fieldDataType.timeSamples = {0: \"float\", 1: \"half\"}"
    after := "token fieldDataType.timeSamples = {0: \"float\", 1: \"invalidTestToken\"}"
    common := "asset filePath = @frame.vdb@"
    checks := fun bad => fieldAssetDataType "OpenVDBAsset" true .unauthored
      [.token "float", .token (if bad then "invalidTestToken" else "half")] },
  { id := "particle-harmonics", kind := "ParticleField3DGaussianSplat", rule := "vol.particleField.shCount"
    before := "float3[] radiance:sphericalHarmonicsCoefficients = [(1,1,1), (1,1,1)]"
    after := "float3[] radiance:sphericalHarmonicsCoefficients = [(1,1,1)]"
    common := "point3f[] positions = [(0,0,0), (1,0,0)]\nuniform int radiance:sphericalHarmonicsDegree = 0"
    checks := fun bad => (0, if sphericalHarmonicsSize (some 2) 0 (if bad then 1 else 2)
      = .warning then 1 else 0) }]

def render (probe : Probe) (weakBad : Bool) : Json :=
  let select := fun bad => if bad then probe.after else probe.before
  let strongBad := !weakBad
  let resolved := (strongest [some strongBad, some weakBad]).getD weakBad
  let wrap := fun specifier body => probe.parentNames.foldr
    (fun name inner => specifier ++ " " ++ reprStr name ++ " {\n" ++ inner ++ "}\n") body
  let weakBody := "def " ++ probe.kind ++ " \"Subject\"" ++ probe.metadata ++
    " {\n" ++ probe.common ++ "\n" ++ select weakBad ++ "\n}\n"
  let rootBody := "over \"Subject\" {\n" ++ select strongBad ++ "\n}\n"
  let weak := "#usda 1.0\n" ++ wrap "def Scope" weakBody ++ probe.siblings
  let root := "#usda 1.0\n(subLayers = [@weak.usda@])\n" ++ wrap "over" rootBody
  Json.mkObj <| [
    ("id", toJson (probe.id ++ if weakBad then "-fix" else "-break")),
    ("weak", toJson weak), ("root", toJson root), ("rule", toJson probe.rule),
    ("weakCounts", toJson (if probe.composedOnly then (0, 0) else probe.checks weakBad)),
    ("diagnosticPrim", toJson probe.diagnosticPrim),
    ("composedCounts", toJson (probe.checks resolved))] ++
    (if probe.composedOnly then [("composedOnly", toJson true)] else []) ++
    ((probe.flattenedChecks.map fun checks => [("flattenedCounts", toJson (checks resolved))]).getD []) ++
    (if probe.materialXPorts.isEmpty then [] else [("materialXPorts", toJson
      (probe.materialXPorts.map fun (node, output, name, type) => Json.mkObj
        [("node", toJson node), ("output", toJson output),
         ("name", toJson name), ("type", toJson type)]))]) ++
    ((probe.errorTimes.map fun times =>
      [("weakErrorTimes", toJson (times weakBad)),
       ("composedErrorTimes", toJson (times resolved))]).getD [])

def files : List (String × String) :=
  let probes := cases.flatMap fun probe => [render probe true, render probe false]
  [("domain-composed-validation-vectors.json", (toJson probes).pretty ++ "\n")]

end Gen.DomainComposedValidation

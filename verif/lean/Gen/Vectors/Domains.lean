import UsdSpec.Domains.Validation
import UsdSpec.Domains.SkeletonValidation
import UsdSpec.Domains.VolumeValidation
import Lean.Data.Json
import UsdSpec.Domains.UsdGeom
import UsdSpec.Domains.UsdSkel
import UsdSpec.Domains.UsdPhysics
import UsdSpec.Domains.UsdMtlx
import UsdSpec.Domains.UsdVol

namespace Gen.DomainsVec

open UsdSpec.Domains UsdSpec.Domains.VolumeValidation UsdSpec.Domains.SkeletonValidation

private def countRow (schema property rule : String) (errors warnings : Nat) : String :=
  "{" ++ String.intercalate ", "
    [reprStr schema, reprStr property, reprStr rule, toString errors, toString warnings] ++ "},"

private def row (schema property rule : String) (result : Diagnostic) : String :=
  countRow schema property rule (if result = .error then 1 else 0)
    (if result = .warning then 1 else 0)

private def array (entries : List String) : String :=
  "[" ++ String.intercalate ", " entries ++ "]"

private def meshSizeRows : List String :=
  [([3], [0, 1, 2]), ([3, 2], [0, 1, 2]), ([0, -2, 1], [0]), ([], [])].map
    fun (counts, indices) =>
      row "Mesh" ("int[] faceVertexCounts = " ++ array (counts.map toString) ++
        "\nint[] faceVertexIndices = " ++ array (indices.map toString)) "geom.mesh.topology.size"
        (if meshIndexCountMatches (some counts) (some indices) then .none else .error)

private def meshIndexRows : List String :=
  [[0, 1, 2], [-1, 0, 3], [], [2, 2, 2]].map fun indices =>
    countRow "Mesh" ("point3f[] points = [(0,0,0),(1,0,0),(0,1,0)]\nint[] faceVertexIndices = " ++
      array (indices.map toString)) "geom.mesh.topology.index" (meshInvalidIndexCount (some 3) indices) 0

private def skelOracleCases : List (List String) :=
  [[], ["root"], ["root", "root/child"], ["root", "root/gap/child"],
   ["root/child", "root"], ["root", "root/branch/child", "root/branch"],
   ["root", "branch", "root/gap/child"], ["one/leaf", "two/leaf"]]

private def skeletonTopologyRows : List String :=
  (skelOracleCases ++ [["root", "root", "root/child"]]).map fun joints =>
    let (errors, warnings) := skeletonTopology joints
    countRow "Skeleton" ("uniform token[] joints = " ++ array (joints.map reprStr))
      "geom.skel.skeleton.topology" errors warnings

private def limitAttribute (name : String) : JointLimitValue → String
  | .absent => ""
  | .invalid => "token physics:" ++ name ++ " = \"not-a-number\"\n"
  | .negativeInfinity => "float physics:" ++ name ++ " = -inf\n"
  | .positiveInfinity => "float physics:" ++ name ++ " = inf\n"
  | .finite value => "float physics:" ++ name ++ " = " ++ toString value ++ "\n"

private def axisLimitRows : List String :=
  [(.negativeInfinity, .positiveInfinity), (.negativeInfinity, .finite 0),
   (.finite 3, .positiveInfinity), (.positiveInfinity, .negativeInfinity),
   (.finite 3, .finite 2), (.invalid, .absent)].map fun (lower, upper) =>
     countRow "PhysicsRevoluteJoint" (limitAttribute "lowerLimit" lower ++
       limitAttribute "upperLimit" upper) "physics.joint.limit" (jointLimitErrors lower upper .absent .absent) 0

private def coneLimitRows : List String :=
  [.finite (-1), .finite (-4), .finite 180, .finite 181, .positiveInfinity, .invalid].map
    fun value => countRow "PhysicsSphericalJoint" (limitAttribute "coneAngle0Limit" value)
      "physics.joint.limit" (jointLimitErrors .absent .absent value .absent) 0

private def distanceLimitRows : List String :=
  [(.finite (-1), .finite (-1)), (.finite 5, .finite (-1)), (.finite (-2), .finite 5),
   (.finite 5, .finite 2), (.negativeInfinity, .positiveInfinity)].map fun (lower, upper) =>
    countRow "PhysicsDistanceJoint" (limitAttribute "minDistance" lower ++
      limitAttribute "maxDistance" upper) "physics.joint.distance" (distanceLimitErrors lower upper) 0

private def gravityRows : List String :=
  [(.negativeInfinity, "(0,0,0)", true), (.finite (-1), "(0,-1,0)", true),
   (.finite 0, "(0,-1,0)", true), (.positiveInfinity, "(0,inf,0)", false),
   (.invalid, "(0,-1,0)", true)].map fun (magnitude, direction, valid) =>
    countRow "PhysicsScene" (limitAttribute "gravityMagnitude" magnitude ++
      "vector3f physics:gravityDirection = " ++ direction) "physics.scene.gravity"
      (sceneGravityErrors magnitude valid) 0

private def forceRows : List String :=
  [("breakForce", true, .positiveInfinity), ("breakTorque", true, .positiveInfinity),
   ("breakForce", true, .negativeInfinity), ("breakTorque", true, .finite (-1)),
   ("mass", false, .finite 0), ("mass", false, .positiveInfinity)].map
    fun (field, unbounded, value) =>
      row "PhysicsRevoluteJoint" (limitAttribute field value) "physics.value.range"
        (if physicalScalarValid unbounded value then .none else .error)

private def driveRows : List String :=
  [("maxForce", "inf", .positiveInfinity), ("maxForce", "-inf", .negativeInfinity),
   ("maxForce", "0", .finite 0), ("damping", "inf", .positiveInfinity),
   ("stiffness", "-2", .finite (-2)), ("targetPosition", "-1", .finite (-1)),
   ("targetVelocity", "-inf", .negativeInfinity)].map fun (field, literal, value) =>
    row "PhysicsRevoluteJoint" ("float drive:angular:physics:" ++ field ++ " = " ++ literal)
      "physics.drive.value" (if driveValueValid field value then .none else .error)

private def centerOfMassRows : List String :=
  [("(-inf,-inf,-inf)", .negativeInfinity, .negativeInfinity, .negativeInfinity),
   ("(-inf,0,-inf)", .negativeInfinity, .finite 0, .negativeInfinity),
   ("(0,1,2)", .finite 0, .finite 1, .finite 2)].map fun (literal, x, y, z) =>
    row "PhysicsScene" ("point3f physics:centerOfMass = " ++ literal) "physics.inertia"
      (if centerOfMassValid x y z then .none else .error)

private def materialXVersionRows : List String :=
  [(.absent, ""), (.absent, "string config:mtlx:version"),
   (.absent, "string config:mtlx:version = None"), (.string "1.39", "string config:mtlx:version = \"1.39\""),
   (.string "2.0", "string config:mtlx:version = \"2.0\""),
   (.string "", "string config:mtlx:version = \"\""),
   (.incompatible, "token config:mtlx:version = \"1.39\"")].map fun (value, text) =>
     row "Material" text "shade.materialX.version" (materialXVersion value)

private def volumeFieldRows : List String :=
  [
    row "Volume" "float field:density = 1" "vol.volume.fieldRel"
      (volumeFieldRelationship .attribute),
    row "Volume" "rel field:density" "vol.volume.fieldRel"
      (volumeFieldRelationship (.targets 0)),
    row "Volume" "rel field:density = </Scene/F>" "vol.volume.fieldRel"
      (volumeFieldRelationship (.targets 1)),
    row "Volume" "rel field:density = </Scene/F>" "vol.volume.fieldTargetType"
      (volumeFieldTargetType 1 .volumeField),
    row "Volume" "rel field:density = </Scene/NotAField>" "vol.volume.fieldTargetType"
      (volumeFieldTargetType 1 .other),
    row "Volume" "rel field:density = </Outside>" "vol.volume.fieldTargetType"
      (volumeFieldTargetType 1 .unknown)
  ]

private def volumeTokenRows (schema property rule : String) : List String :=
  let allowed := allowedTokens schema property
  (allowed ++ ["invalidTestToken"]).map fun token =>
    row schema ("token " ++ property ++ " = " ++ reprStr token) rule
      (tokenProperty schema property (.token token))

private def fieldTypeRows (schema : String) : List String :=
  let cases : List (String × Bool × TokenOpinion × List TokenOpinion) := [
    ("", false, .unauthored, []),
    ("token fieldDataType", false, .unauthored, []),
    ("rel fieldDataType", false, .invalid, []),
    ("string fieldDataType = \"float\"", true, .invalid, []),
    ("token fieldDataType.timeSamples = {0: \"float\", 1: \"half\"}",
       true, .unauthored, [.token "float", .token "half"]),
    ("token fieldDataType.timeSamples = {0: \"float\", 1: \"invalidTestToken\"}",
       true, .unauthored, [.token "float", .token "invalidTestToken"]),
  ]
  let allowed := allowedTokens schema "fieldDataType"
  (cases ++ (allowed ++ ["invalidTestToken"]).map (fun token =>
    ("token fieldDataType = " ++ reprStr token, true, TokenOpinion.token token, []))).map
      fun (property, present, default, samples) =>
        let (errors, warnings) := fieldAssetDataType schema present default samples
        countRow schema property "vol.fieldAsset.dataType" errors warnings

private def fieldFileRows : List String :=
  [("OpenVDBAsset", "frame.vdb"), ("Field3DAsset", "frame.f3d")].flatMap fun (schema, file) =>
    let cases : List (String × Bool × Option String × Nat) := [
      ("", false, none, 0), ("rel filePath", false, none, 0),
      ("asset filePath", true, none, 0), ("asset filePath = @@", true, some "", 0),
      ("asset filePath = @" ++ file ++ "@", true, some file, 0),
      ("asset filePath.timeSamples = {0: @" ++ file ++ "@}", true, none, 1)
    ]
    cases.map fun (property, hasAttribute, path, samples) =>
      row schema property "vol.fieldAsset.filePath" (fieldAssetFilePath hasAttribute path samples)

private def gaussian : String := "ParticleField3DGaussianSplat"

private def particlePositions (count : Nat) (full : Bool := true) : String :=
  (if full then "point3f[] positions" else "point3h[] positionsh") ++ " = " ++
    array (List.replicate count "(0,0,0)") ++ "\n"

private def particleArrayRows : List String :=
  let cases : List (Option Nat × Option Nat × Nat) :=
    [(none, none, 1), (some 2, none, 1), (some 2, none, 3), (some 2, none, 2),
     (none, some 2, 2), (none, some 2, 1), (some 1, some 2, 1), (some 0, some 2, 1)]
  cases.map fun (full, half, values) =>
    let props := (full.map (particlePositions · true)).getD "" ++
      (half.map (particlePositions · false)).getD "" ++
      "float[] opacities = " ++ array (List.replicate values "1")
    row gaussian props "vol.particleField.arraySize"
      (particleArraySize (particleCount full half) values)

private def particleProviderRows : List String :=
  ["vol.particleField.position", "vol.particleField.kernel"].flatMap fun rule =>
    [row "ParticleField" "" rule (particleProvider false false),
     row gaussian "" rule (particleProvider true false)]

private def harmonicsRows : List String :=
  let sizes : List (Nat × Int × Nat × Bool) :=
    [(2, 0, 2, true), (2, 0, 1, true), (2, 1, 8, true), (2, 1, 9, false),
     (2, 1, 8, false), (0, 1, 0, true), (1, -1, 1, true), (1, 3, 16, true)]
  let counts := sizes.map fun (particles, degree, coefficients, full) =>
    let coefficientDecl := if full then "float3[] radiance:sphericalHarmonicsCoefficients"
      else "half3[] radiance:sphericalHarmonicsCoefficientsh"
    row gaussian (particlePositions particles ++
      "uniform int radiance:sphericalHarmonicsDegree = " ++ toString degree ++ "\n" ++
      coefficientDecl ++ " = " ++ array (List.replicate coefficients "(1,1,1)"))
      "vol.particleField.shCount" (sphericalHarmonicsSize (some particles) degree coefficients)
  counts ++ [row gaussian (particlePositions 1 ++ "uniform int radiance:sphericalHarmonicsDegree = -1")
    "vol.particleField.shDegree" (sphericalHarmonicsDegree (some 1) (-1)),
    row gaussian (particlePositions 1 ++ "uniform int radiance:sphericalHarmonicsDegree = 0")
    "vol.particleField.shDegree" (sphericalHarmonicsDegree (some 1) 0)]

private def extendedVolumeRows : List String :=
  fieldTypeRows "OpenVDBAsset" ++ fieldTypeRows "Field3DAsset" ++ fieldFileRows ++
  volumeTokenRows "OpenVDBAsset" "fieldClass" "vol.fieldAsset.fieldClass" ++
  volumeTokenRows "OpenVDBAsset" "vectorDataRoleHint" "vol.fieldAsset.vectorDataRoleHint" ++
  volumeTokenRows gaussian "projectionModeHint" "vol.particleField.projectionModeHint" ++
  volumeTokenRows gaussian "sortingModeHint" "vol.particleField.sortingModeHint" ++
  particleArrayRows ++ particleProviderRows ++ harmonicsRows

private def skelJointsTwo : String :=
  "uniform token[] joints = " ++ array (["root", "root/child"].map reprStr) ++ "\n"

private def poseRows : List String :=
  let cases : List (String × ArrayOpinion × List ArrayOpinion) := [
    ("float3[] translations", .absent, []),
    ("float3[] translations = [(0,0,0),(1,0,0)]", .array 2, []),
    ("float3[] translations = [(0,0,0)]", .array 1, []),
    ("float3[] translations.timeSamples = {0: [(0,0,0)], 1: [], 2: [(0,0,0),(1,0,0)]}",
      .absent, [.array 1, .array 0, .array 2]),
    ("quatf[] rotations.timeSamples = {0: None, 1: [(1,0,0,0),(1,0,0,0)]}",
      .absent, [.absent, .array 2]),
    ("half3[] scales.timeSamples = {0: [(1,1,1)]}", .absent, [.array 1]),
    ("float translations.timeSamples = {0: 1}", .absent, [.other])
  ]
  cases.map fun (props, default, samples) =>
    let (errors, warnings) := arrayCardinality (some 2) default samples
    countRow "SkelAnimation" (skelJointsTwo ++ props) "geom.skel.animation.transforms"
      errors warnings

private def animationJointRows : List String :=
  [("", false), ("uniform token[] joints", false), (skelJointsTwo, true)].map
    fun (props, joints) => row "SkelAnimation" props "geom.skel.animation.joints"
      (animationJoints joints)

private def blendWeightRows : List String :=
  let cases : List (Option (List String) × String × Bool × ArrayOpinion × List ArrayOpinion) := [
    (none, "", false, .absent, []),
    (none, "float[] blendShapeWeights", true, .absent, []),
    (some ["Smile", "Frown"], "float[] blendShapeWeights = [0,1]", true, .array 2, []),
    (some ["Smile", "Frown"], "float[] blendShapeWeights = [0]", true, .array 1, []),
    (some ["Smile", "Smile", ""], "float[] blendShapeWeights = [0]", true, .array 1, []),
    (some ["Smile"], "float[] blendShapeWeights.timeSamples = {0: [], 1: [1]}", true,
      .absent, [.array 0, .array 1])
  ]
  cases.map fun (names, props, weights, default, samples) =>
    let namesText := (names.map fun tokens =>
      "uniform token[] blendShapes = " ++ array (tokens.map reprStr) ++ "\n").getD ""
    let (errors, warnings) := animationBlendShapes names weights default samples
    countRow "SkelAnimation" (namesText ++ props) "geom.skel.animation.blendShapes" errors warnings

private def blendOffsetsTwo : String :=
  "uniform vector3f[] offsets = [(0,0,0),(1,0,0)]\n"

private def blendOffsetRows : List String :=
  [("", ArrayOpinion.absent), ("uniform vector3f[] offsets", .absent),
   ("uniform vector3f[] offsets = []", .array 0), (blendOffsetsTwo, .array 2)].map
    fun (props, offsets) => row "BlendShape" props "geom.skel.blendShape.offsets"
      (blendShapeOffsets offsets)

private def blendNormalRows : List String :=
  let cases : List (String × ArrayOpinion × List ArrayOpinion) := [
    ("uniform vector3f[] normalOffsets = [(0,0,0),(0,1,0)]", .array 2, []),
    ("uniform vector3f[] normalOffsets = [(0,0,0)]", .array 1, []),
    ("uniform vector3f[] normalOffsets.timeSamples = {0: [], 1: [(0,0,0),(0,1,0)]}",
       .absent, [.array 0, .array 2])
  ]
  cases.map fun (props, default, samples) =>
    let (errors, warnings) := arrayCardinality (some 2) default samples
    countRow "BlendShape" (blendOffsetsTwo ++ props) "geom.skel.blendShape.normalOffsets"
      errors warnings

private def blendIndexRows : List String :=
  [[0,1], [0], [-1,1], [1,1], [-1,0,0]].map fun indices =>
    let (errors, warnings) := blendShapeIndices (some 2) indices
    countRow "BlendShape" (blendOffsetsTwo ++ "uniform int[] pointIndices = " ++
      array (indices.map toString)) "geom.skel.blendShape.pointIndices" errors warnings

private def skeletonRestRows : List String :=
  let matrix := "((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1))"
  [("uniform matrix4d[] bindTransforms", ArrayOpinion.absent),
   ("uniform matrix4d[] restTransforms = " ++ array [matrix], .array 1),
   ("uniform matrix4d[] bindTransforms = " ++ array [matrix, matrix], .array 2)].map
    fun (props, default) => row "Skeleton" (skelJointsTwo ++ props)
      "geom.skel.skeleton.transforms" (skeletonTransforms 2 default)

private def inbetweenRows : List String :=
  let cases : List (String × Bool × Nat) := [
    ("uniform point3f[] inbetweens:half = [(0,0,0),(1,0,0)]", false, 2),
    ("uniform point3f[] inbetweens:half = [(0,0,0),(1,0,0)] (weight = 0.5)", true, 2),
    ("uniform point3f[] inbetweens:half = [(0,0,0)] (weight = 0.5)", true, 1),
    ("vector3f[] inbetweens:half:normalOffsets = [(0,0,0),(1,0,0)]", true, 2),
    ("vector3f[] inbetweens:half:normalOffsets = [(0,0,0)]", true, 1)
  ]
  cases.map fun (props, weight, size) =>
    let (errors, warnings) := blendShapeInbetween (some 2) weight (.array size)
    countRow "BlendShape" (blendOffsetsTwo ++ props) "geom.skel.blendShape.inbetween"
      errors warnings

private def skelDataRows : List String :=
  poseRows ++ animationJointRows ++ blendWeightRows ++ blendOffsetRows ++
  blendNormalRows ++ blendIndexRows ++ skeletonRestRows ++ inbetweenRows

private def pointInstancerRows : List String :=
  let positions := "point3f[] positions = [(0,0,0),(1,0,0)]"
  let prototypes := "\nrel prototypes = [</Scene/F>, </Scene/G>]"
  let indexRows := [[], [1], [1, 0], [-1, 2], [0, 0]].map fun indices =>
    countRow "PointInstancer" (positions ++ prototypes ++
      "\nint[] protoIndices = " ++ array (indices.map toString)) "geom.pointInstancer.indices"
      (pointInstancerIndexErrors (.relationship [true, true]) (some 2) (some indices)) 0
  let prototypeRows := [("", PrototypeOpinion.absent),
      ("\nrel prototypes = []", .relationship []), (prototypes, .relationship [true, true]),
      ("\nint prototypes = 0", .attribute)].map fun (property, opinion) =>
    countRow "PointInstancer" (positions ++ property) "geom.pointInstancer.prototypes"
      (prototypeErrors opinion) 0
  let rotationRows := [
    ("quatf[] orientationsf = [(1,0,0,0),(1,0,0,0)]", ArrayOpinion.array 2, []),
    ("quatf[] orientationsf = [(1,0,0,0)]", .array 1, []),
    ("quatf[] orientationsf.timeSamples = {0: [(1,0,0,0),(1,0,0,0)], 1: [(1,0,0,0)]}",
      .absent, [.array 2, .array 1])].map fun (property, default, samples) =>
    let (errors, warnings) := arrayCardinality (some 2) default samples
    countRow "PointInstancer" (positions ++ prototypes ++ "\n" ++ property)
      "geom.pointInstancer.arraySize" errors warnings
  indexRows ++ prototypeRows ++ rotationRows

private def pointRows : List String :=
  let points := "point3f[] points = [(0,0,0),(1,0,0)]\n"
  let cardinality := [
    ("int64[] ids = [7,8]", PointsArray.ids, 2), ("int64[] ids = [7]", .ids, 1),
    ("float[] widths = [1]", .widths, 1), ("float[] widths = []", .widths, 0),
    ("normal3f[] normals = [(0,0,1)]", .normals, 1),
    ("vector3f[] velocities = [(0,0,0)]", .velocities, 1),
    ("vector3f[] accelerations = [(0,0,0),(0,0,0)]", .accelerations, 2)].map
    fun (props, property, size) =>
      row "Points" (points ++ props) "geom.points.size"
        (if pointsArraySizeValid property 2 size then .none else .error)
  let widths := [
    ("float[] widths = [-1,inf]", [JointLimitValue.finite (-1), .positiveInfinity]),
    ("float[] widths = [0,1]", [.finite 0, .finite 1])].map fun (props, values) =>
      countRow "Points" (points ++ props) "geom.points.widths" (invalidPointWidths values) 0
  cardinality ++ widths

private def curveVaryingRows : List String :=
  [("", CurveBasis.bezier, false, [4, 7], 5), ("", .bezier, false, [4, 7], 2),
   ("basis = \"bspline\"\nuniform token wrap = \"pinned\"", .bspline, false, [4, 5], 5),
   ("basis = \"catmullRom\"\nuniform token wrap = \"periodic\"", .catmullRom, true, [4, 5], 9),
   ("basis = \"bezier\"\nuniform token wrap = \"periodic\"", .bezier, true, [6, 9], 5),
   ("type = \"linear\"\nuniform token wrap = \"periodic\"", .linear, true, [3, 4], 9),
   ("type = \"linear\"", .linear, false, [3, 4], 7)].map
    fun (tokens, basis, periodic, counts, widths) =>
      let props := if tokens.isEmpty then "" else "uniform token " ++ tokens ++ "\n"
      row "BasisCurves" (props ++ "int[] curveVertexCounts = " ++
        array (counts.map toString) ++ "\nfloat[] widths = " ++ array (List.replicate widths "1") ++
        " (interpolation = \"varying\")") "geom.curves.widths"
        (curveVaryingWidths basis periodic counts widths)

private def cameraRows : List String :=
  let clipping := [
    ("(0,10)", JointLimitValue.finite 0, JointLimitValue.finite 10),
    ("(1,1)", .finite 1, .finite 1), ("(-1,10)", .finite (-1), .finite 10),
    ("(0,inf)", .finite 0, .positiveInfinity)].map fun (literal, near, far) =>
      row "Camera" ("float2 clippingRange = " ++ literal) "geom.camera.range"
        (if cameraClippingValid near far then .none else .error)
  let shutter := [
    ("double shutter:open = -1\ndouble shutter:close = -1", JointLimitValue.finite (-1), JointLimitValue.finite (-1)),
    ("double shutter:open = 1\ndouble shutter:close = 0", .finite 1, .finite 0),
    ("double shutter:open = 0\ndouble shutter:close = inf", .finite 0, .positiveInfinity),
    ("double shutter:open = 0", .finite 0, .absent)].map fun (props, opens, closes) =>
      row "Camera" props "geom.camera.shutter"
        (if cameraShutterValid opens closes then .none else .error)
  let optics := [
    ("float focalLength = 0", false, JointLimitValue.finite 0),
    ("float horizontalAperture = inf", false, .positiveInfinity),
    ("float verticalAperture = 5", false, .finite 5),
    ("float fStop = 0", true, .finite 0), ("float fStop = -1", true, .finite (-1))].map
    fun (props, allowZero, value) =>
      row "Camera" props "geom.camera.optics"
        (if cameraOpticValid allowZero value then .none else .error)
  let pulsed := countRow "Camera"
    "float2 clippingRange = (0,10)\nfloat2 clippingRange.timeSamples = {0: (0,10), 1: (4,1), 2: None, 3: (0,inf)}"
    "geom.camera.range" (cameraClippingErrors [some (.finite 0,.finite 10),
      some (.finite 0,.finite 10), some (.finite 4,.finite 1), none,
      some (.finite 0,.positiveInfinity)]) 0
  let sampledOptics := [
    ("float focalLength.timeSamples = {0: 35, 1: 50, 2: None}", false,
      [JointLimitValue.finite 35, .finite 50, .absent]),
    ("float verticalAperture.timeSamples = {0: 10, 1: 0, 2: inf}", false,
      [.finite 10, .finite 0, .positiveInfinity]),
    ("float fStop.timeSamples = {0: 0, 1: -1}", true, [.finite 0, .finite (-1)])].map
    fun (props, allowZero, samples) =>
      countRow "Camera" props "geom.camera.optics"
        ((samples.filter (!cameraOpticValid allowZero ·)).length) 0
  clipping ++ shutter ++ optics ++ [pulsed] ++ sampledOptics

private def skinningRows : List String :=
  let influences := fun name type value interp =>
    type ++ "[] primvars:skel:" ++ name ++ " = [" ++ value ++ "] (elementSize = 1" ++
      (interp.map (fun token => "\ninterpolation = " ++ reprStr token)).getD "" ++ "\n)\n"
  let interpolation := [(some "constant", some "constant"), (some "vertex", some "vertex"),
      (some "vertex", some "constant"), (some "varying", some "varying"), (none, some "vertex")]
    |>.map fun (indices, weights) =>
      countRow "Mesh" (influences "jointIndices" "int" "0" indices ++
        influences "jointWeights" "float" "1" weights) "geom.skel.skinning.interpolation"
        (influenceInterpolationErrors indices weights) 0
  let bounds := [0, 1, -1].map fun index =>
    countRow "Mesh" ("uniform token[] skel:joints = [\"root\"]\n" ++
      influences "jointIndices" "int" (toString index) (some "constant") ++
      influences "jointWeights" "float" "1" (some "constant")) "geom.skel.skinning.index"
      (influenceIndexErrors (some 1) none [index]) 0
  interpolation ++ bounds

private def skinningWeightRows : List String :=
  let fields := fun indices weights =>
    "int[] primvars:skel:jointIndices = " ++ indices ++ " (\nelementSize = 2\ninterpolation = \"constant\"\n)\n" ++
    "float[] primvars:skel:jointWeights = " ++ weights ++ " (\nelementSize = 2\ninterpolation = \"constant\"\n)"
  let groups := [
    ("[0.25,0.75]", [some (1/4 : Rat), some (3/4)]),
    ("[0,0]", [some 0, some 0]), ("[0.25,0.25]", [some (1/4), some (1/4)]),
    ("[1,inf]", [some 1, none])].map fun (weights, values) =>
      row "Mesh" (fields "[0,1]" weights) "geom.skel.skinning.weight" (influenceWeightGroup values)
  let sizes := [("[0,1]", "[0.25,0.75]", 2, 2), ("[0]", "[1]", 1, 1),
    ("[0,1]", "[1]", 2, 1)].map fun (indices, weights, ni, nw) =>
      countRow "Mesh" (fields indices weights) "geom.skel.skinning.size"
        (influenceSizeErrors ni nw 2 2) 0
  groups ++ sizes

private def skinningGroupRows : List String :=
  [("constant", 1), ("constant", 2), ("constant", 0), ("vertex", 2), ("vertex", 1)].map
    fun (interp, groups) =>
      let metadataText := " (\nelementSize = 1\ninterpolation = " ++ reprStr interp ++ "\n)"
      let props := "point3f[] points = [(0,0,0),(1,0,0)]\n" ++
        "int[] primvars:skel:jointIndices = " ++ array (List.replicate groups "0") ++ metadataText ++ "\n" ++
        "float[] primvars:skel:jointWeights = " ++ array (List.replicate groups "1") ++ metadataText
      row "Mesh" props "geom.skel.skinning.size"
        (if influenceGroupCountValid interp (some 2) groups groups then .none else .error)

private def indexedSkinningRows : List String :=
  let base := "point3f[] points = [(0,0,0),(1,0,0)]\n" ++
    "int[] primvars:skel:jointIndices = [0] (\nelementSize = 1\ninterpolation = \"vertex\"\n)\n" ++
    "float[] primvars:skel:jointWeights = [1,1] (\nelementSize = 1\ninterpolation = \"vertex\"\n)\n"
  let source := fun indices => base ++ "int[] primvars:skel:jointIndices:indices = " ++
    array (indices.map toString)
  let sizes := [[0,0], [0], []].map fun indices =>
    let errors := match resolvedInfluenceGroups 1 (some indices) with
      | none => 0
      | some groups =>
        (if groups != 2 then 1 else 0) +
          (if influenceGroupCountValid "vertex" (some 2) groups 2 then 0 else 1)
    countRow "Mesh" (source indices) "geom.skel.skinning.size" errors 0
  let selectors := [[0,0], [-1,1]].map fun indices =>
    countRow "Mesh" (source indices) "geom.skel.skinning.selector"
      (influenceSelectorErrors 1 indices) 0
  sizes ++ selectors

private def skinningMethodRows : List String :=
  ["classicLinear", "dualQuaternion", "unsupported"].map fun token =>
    row "Mesh" ("token primvars:skel:skinningMethod = " ++ reprStr token)
      "geom.skel.skinning.method" (if skinningMethodValid (.token token) then .none else .error)

private def fieldIndexRows : List String :=
  ["OpenVDBAsset", "Field3DAsset"].flatMap fun schema =>
    [("", [none]), ("int fieldIndex = 0", [some 0]),
     ("int fieldIndex = -1", [some (-1)]),
     ("int fieldIndex.timeSamples = {0: -1, 1: 1, 2: -2, 3: None}",
       [some (-1), some 1, some (-2), none])].map fun (props, indices) =>
       countRow schema props "vol.fieldAsset.fieldIndex" (negativeFieldIndexCount indices) 0

private def cameraTokenRows : List String :=
  [("projection", "token projection = \"orthographic\"", [.token "orthographic"]),
   ("projection", "token projection = \"fisheye\"", [.token "fisheye"]),
   ("stereoRole", "token stereoRole = \"right\"", [.token "right"]),
   ("stereoRole", "token stereoRole = \"both\"", [.token "both"]),
   ("projection", "token projection.timeSamples = {0: \"perspective\", 1: \"orthographic\", 2: None}",
     [.token "perspective", .token "orthographic", .unauthored]),
   ("stereoRole", "token stereoRole.timeSamples = {0: \"mono\", 1: \"both\", 2: \"invalid\"}",
     [.token "mono", .token "both", .token "invalid"])].map fun (property, props, values) =>
    row "Camera" props "geom.camera.tokens"
      (if cameraTokensValid property values then .none else .error)

private def nurbsPatchRows : List String :=
  [("int uVertexCount = 2\nint uOrder = 2\ndouble[] uKnots = [0,0,1,1]", 2, 2, some 4, true),
   ("int uVertexCount = 2\nint uOrder = 2\ndouble[] uKnots = [0,1,0]", 2, 2, some 3, false),
   ("int vVertexCount = 1\nint vOrder = 2", 1, 2, none, true),
   ("int vVertexCount = 2\nint vOrder = 0", 2, 0, none, true)].map
    fun (props, vertices, order, knots, ordered) =>
      countRow "NurbsPatch" props "geom.nurbsPatch.topology"
        (nurbsAxisErrors vertices order knots ordered) 0

private def nurbsRangeRows : List String :=
  [("(1,5)", JointLimitValue.finite 1, JointLimitValue.finite 5),
   ("(0,5)", .finite 0, .finite 5), ("(1,6)", .finite 1, .finite 6),
   ("(3,2)", .finite 3, .finite 2), ("(1,inf)", .finite 1, .positiveInfinity)].map
    fun (literal, low, high) =>
      row "NurbsPatch"
        ("int uVertexCount = 2\nint uOrder = 2\ndouble[] uKnots = [0,1,4,5]\ndouble2 uRange = " ++ literal)
        "geom.nurbsPatch.topology"
        (if nurbsRangeValid (some (1,5)) low high then .none else .error)

private def validationFiles : List (String × String) :=
  [("domain-validation-vectors.inc",
    "// Generated by usdspec-gen (Gen.Vectors.Domains).\n" ++
    String.intercalate "\n" ([
      row "Mesh" "int[] faceVertexCounts = [3]" "geom.mesh.topology.count"
        (if meshFaceCountsValid [3] then .none else .error),
      row "Mesh" "int[] faceVertexCounts = [0]" "geom.mesh.topology.count"
        (if meshFaceCountsValid [0] then .none else .error),
      row "Skeleton" "uniform token[] joints = [\"root\"]" "geom.skel.skeleton.joints"
        (skeletonJoints (some ["root"])),
      row "Skeleton" "uniform token[] joints = []" "geom.skel.skeleton.joints"
        (skeletonJoints (some [])),
      row "Skeleton" "" "geom.skel.skeleton.joints" (skeletonJoints none),
      row "Skeleton" "uniform token[] joints = [\"/root\"]" "geom.skel.skeleton.joints"
        (skeletonJoints (some ["/root"])),
      row "Skeleton" "uniform token[] joints = [\"root\", \"root\"]"
        "geom.skel.skeleton.joints" (skeletonJoints (some ["root", "root"])),
      row "PhysicsRevoluteJoint" "uniform token physics:axis = \"X\"" "physics.joint.axis"
        (physicsJointAxis (.token "X")),
      row "PhysicsRevoluteJoint" "uniform token physics:axis = \"W\"" "physics.joint.axis"
        (physicsJointAxis (.token "W")),
      row "Material" "" "shade.materialX.configAPI" (materialXConfig false false true),
      row "Material" "string config:mtlx:version = \"1.38\"" "shade.materialX.configAPI"
        (materialXConfig true false true),
      row "Volume" "rel field:density = </Scene/F>" "vol.volume.fieldTargetCount"
        (volumeFieldTargetCount 1),
      row "Volume" "rel field:density = [</Scene/F>, </Scene/G>]" "vol.volume.fieldTargetCount"
        (volumeFieldTargetCount 2)
      , row "Skeleton" "uniform token[] joints = [\"root\"]\nuniform token[] jointNames = []"
        "geom.skel.skeleton.jointNames" (skeletonJointNameCount 1 0)
      , row "Skeleton" "uniform token[] joints = [\"root\"]\nuniform token[] jointNames = [\"Root\"]"
        "geom.skel.skeleton.jointNames" (skeletonJointNameCount 1 1)
    ] ++ meshSizeRows ++ meshIndexRows ++ skeletonTopologyRows ++
      axisLimitRows ++ coneLimitRows ++ distanceLimitRows ++ gravityRows ++ forceRows ++
      driveRows ++ centerOfMassRows ++ materialXVersionRows ++
      volumeFieldRows ++ extendedVolumeRows ++ skelDataRows ++ pointInstancerRows ++ curveVaryingRows ++ pointRows ++ cameraRows ++ cameraTokenRows ++ skinningRows ++ skinningWeightRows ++ skinningGroupRows ++ indexedSkinningRows ++ skinningMethodRows ++ fieldIndexRows ++ nurbsPatchRows ++ nurbsRangeRows) ++ "\n")]

private def catalogProbe (catalog : List Schema)
    (schemaName primType appliedAPI propertyName : String)
    (instanceName : Option String := none) : String :=
  let contributions := ((lookup catalog schemaName).map fun schema =>
    SchemaContribution.mk schema instanceName).toList
  let type := (effectiveProperty contributions propertyName).map Property.valueType
  "{" ++ String.intercalate ", "
    ([primType, appliedAPI, propertyName, type.getD ""].map reprStr) ++ "},"

private def skelOracleFile : String :=
  let data := skelOracleCases.map fun joints =>
    Lean.Json.mkObj [("joints", Lean.toJson joints),
      ("parents", Lean.toJson (skeletonParentIndices joints))]
  (Lean.toJson data).pretty ++ "\n"

private def skelDeformationFile : String :=
  let samples : List Lean.Json := [0, 1, 2].map fun (time : Int) =>
    let t : Rat := time
    let coordinates := [blendTranslatedCoordinate 0 [(1/4, 2*t), (3/4, 4*t)],
      blendTranslatedCoordinate 1 [(1, 2*t)], blendTranslatedCoordinate 0 [(1, 4*t)]]
    let encode := fun (values : List Rat) => Lean.toJson (values.map fun q => (q.num, q.den))
    let diagonal := [
      blendDiagonalCoordinate 0 [(1/4, -2, 2*t), (3/4, -2, -2*t)], 0, 0,
      blendDiagonalCoordinate 1 [(1, -2, 2*t)], 0, 0,
      blendDiagonalCoordinate 0 [(1, -2, -2*t)],
      blendDiagonalCoordinate 1 [(1, -3, 0)], 0]
    -- A quaternion (3/5, 0, 0, 4/5) rotates the scaled XY plane.
    -- The child translation is first transformed by the parent's linear part.
    let a : Rat := -14/25
    let b : Rat := -72/25
    let c : Rat := 48/25
    let d : Rat := -21/25
    let rootX := 2*t
    let childX := rootX + a*(2*t)
    let childY := c*(2*t)
    let rotated := [
      blendPlanarCoordinate (0,0) [(1/4,a,b,rootX), (3/4,a,b,childX)],
      blendPlanarCoordinate (0,0) [(1/4,c,d,0), (3/4,c,d,childY)], 0,
      blendPlanarCoordinate (1,0) [(1,a,b,rootX)],
      blendPlanarCoordinate (1,0) [(1,c,d,0)], 0,
      blendPlanarCoordinate (0,1) [(1,a,b,childX)],
      blendPlanarCoordinate (0,1) [(1,c,d,childY)], 0]
    let (dualX, dualY) := dualQuaternionUnitX (1/4) (3/4)
    Lean.Json.mkObj [("time", Lean.toJson time),
      ("dualQuaternionProbe", encode [dualX, dualY, 0]),
      ("translation", encode (coordinates.zipWith (fun x y => [x, y, 0]) [0, 0, 1]).flatten),
      ("diagonal", encode diagonal), ("rotated", encode rotated)]
  (Lean.toJson samples).pretty ++ "\n"

private def volumeGridRows : String :=
  let grids := [("sdf", "fogVolume"), ("sdf", "levelSet")]
  let rows := [("sdf", 0, "float", ""), ("sdf", 1, "double", ""), ("", 1, "", ""),
      ("missing", 0, "float", ""), ("sdf", 2, "float", ""), ("sdf", -1, "float", ""),
      ("sdf", 0, "float", "levelSet"), ("sdf", 1, "double", "fogVolume"),
      ("sdf", 1, "float", "levelSet")].map
    fun (name, index, hint, classHint) =>
      let grid := selectFieldGrid grids name index
      let className := (grid.map fun g => effectiveFieldClass g.2 classHint).getD ""
      let classWarnings := if grid.any (fun g => fieldClassMismatch g.2 classHint) then 1 else 0
      let typeWarnings := if grid.isSome && !floatFieldTypeMatches hint false then 1 else 0
      "{ " ++ String.intercalate ", " [reprStr name, toString index, reprStr hint,
        reprStr classHint, reprStr className,
        toString (grid.any (fun g => rendersAsLevelSet g.2 classHint)),
        toString (classWarnings + typeWarnings)] ++ " },"
  "// Generated by usdspec-gen.\n" ++ String.intercalate "\n" rows ++ "\n"

def files : List (String × String) :=
  validationFiles ++ [("domain-skeleton-topology-vectors.json", skelOracleFile),
    ("domain-volume-grid-vectors.inc", volumeGridRows),
    ("domain-skeleton-deformation-vectors.json", skelDeformationFile),
    ("domain-catalog-vectors.inc",
    "// Generated by usdspec-gen (Gen.Vectors.Domains).\n" ++
    String.intercalate "\n" [
      catalogProbe UsdGeom.catalog "Mesh" "Mesh" "" "faceVertexCounts",
      catalogProbe UsdSkel.catalog "Skeleton" "Skeleton" "" "bindTransforms",
      catalogProbe UsdPhysics.catalog "PhysicsRevoluteJoint" "PhysicsRevoluteJoint" "" "physics:axis",
      catalogProbe UsdPhysics.catalog "PhysicsDriveAPI" "PhysicsRevoluteJoint"
        "PhysicsDriveAPI:angular" "drive:angular:physics:type" (some "angular"),
      catalogProbe UsdMtlx.catalog "MaterialXConfigAPI" "Material" "MaterialXConfigAPI" "config:mtlx:version",
      catalogProbe UsdVol.catalog "OpenVDBAsset" "OpenVDBAsset" "" "fieldName"
    ] ++ "\n")]

end Gen.DomainsVec

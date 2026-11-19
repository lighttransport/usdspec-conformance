import UsdSpec.LayerOffset
import UsdSpec.Domains.UsdGeom

namespace UsdSpec.Domains

inductive Diagnostic where
  | none | warning | error
  deriving DecidableEq, Repr

/-- Cardinality of the built-in mesh normals for each interpolation domain. -/
def meshNormalCount (interpolation : Option String) (points faces corners : Option Nat) :
    Option Nat :=
  match interpolation.getD "vertex" with
  | "constant" => some 1
  | "uniform" => faces
  | "vertex" | "varying" => points
  | "faceVarying" => corners
  | _ => none

theorem meshNormalCount_default (points faces corners : Option Nat) :
    meshNormalCount none points faces corners = points := rfl

/-- Validity of the flattened normal count and selected groups. -/
def meshNormalPrimvarValid (expected : Option Nat) (values groupSize : Nat)
    (selectors : Option (List Int)) : Bool :=
  match selectors with
  | none => expected.all (· == values)
  | some rows =>
    groupSize > 0 && expected.all (· == rows.length * groupSize) &&
      rows.all fun row => 0 ≤ row && (row.toNat + 1) * groupSize ≤ values

theorem meshNormalPrimvar_repeat : meshNormalPrimvarValid (some 6) 2 2
    (some [0, 0, 0]) = true := by decide

def meshFaceCountsValid (counts : List Int) : Bool :=
  counts.all (fun count => decide (0 < count))

theorem meshFaceCountsValid_iff (counts : List Int) :
    meshFaceCountsValid counts = true ↔ ∀ count ∈ counts, 0 < count := by
  simp [meshFaceCountsValid, List.all_eq_true]

def jointPathValid (joint : String) : Bool :=
  (joint.splitOn "/").all (fun component => !component.isEmpty)

def skeletonJoints (joints : Option (List String)) : Diagnostic :=
  match joints with
  | none => .warning
  | some paths =>
    if paths.isEmpty || !(paths.all jointPathValid) || !(decide paths.Nodup)
      then .error else .none

theorem skeletonJoints_accepts_iff (paths : List String) :
    skeletonJoints (some paths) = .none ↔
      paths ≠ [] ∧ (∀ path ∈ paths, jointPathValid path = true) ∧ paths.Nodup := by
  cases paths <;> simp [skeletonJoints]

inductive TokenOpinion where
  | unauthored | invalid | token (value : String)
  deriving DecidableEq, Repr

inductive JointBodyTarget where
  | xformable | otherPrim | unresolved | forwardingProperty
  deriving DecidableEq, Repr

def jointBodyCountValid (targets : List JointBodyTarget) : Bool :=
  decide (targets.length ≤ 1)

def jointBodyTargetErrors (targets : List JointBodyTarget) : Nat :=
  (targets.filter (· != .xformable)).length

theorem jointBodyWorldAnchor :
    jointBodyCountValid [] = true ∧ jointBodyTargetErrors [] = 0 := by decide

def collisionGroupsMerge (first second : String) : Bool :=
  !first.isEmpty && first == second

theorem emptyCollisionGroupsDistinct : collisionGroupsMerge "" "" = false := rfl

def filteredGroupWarnings (targets : List (Option Bool)) : Nat :=
  (targets.filter (· == some false)).length

def collisionGroupFilters (inverted listed : Bool) : Bool :=
  if inverted then !listed else listed

theorem invertedCollisionFilter (listed : Bool) :
    collisionGroupFilters true listed = !collisionGroupFilters false listed := rfl

def simulationOwnerTargetWarnings (targets : List (Option Bool)) : Nat :=
  (targets.filter (· == some false)).length

theorem sceneOwnerListHasNoWarnings (count : Nat) :
    simulationOwnerTargetWarnings (List.replicate count (some true)) = 0 := by
  induction count with
  | zero => rfl
  | succ count ih => simpa [simulationOwnerTargetWarnings, List.replicate_succ] using ih

def cameraTokensValid (property : String) (opinions : List TokenOpinion) : Bool :=
  let allowed := ((lookup UsdGeom.catalog "Camera").bind (fun schema =>
    findProperty schema property)).map Property.allowedTokens |>.getD []
  opinions.all fun
    | .unauthored => true
    | .invalid => false
    | .token value => allowed.contains value

def physicsJointAxis : TokenOpinion → Diagnostic
  | .unauthored => .none
  | .invalid => .error
  | .token value => if value ∈ ["X", "Y", "Z"] then .none else .error

def materialXReferencePrimPathValid (path : String) : Bool :=
  path == "/MaterialX" || path.startsWith "/MaterialX/"

def materialXSourceWarning (assetPath : String) (packageEntry : Option String := none) : Bool :=
  let path := packageEntry.getD assetPath
  !path.isEmpty && !(path.endsWith ".mtlx" || path.endsWith ".MTLX")

def materialXHasTerminalSource (targetCounts : List Nat) : Bool :=
  targetCounts.any (· != 0)

theorem emptyMaterialXTerminalsHaveNoSource :
    materialXHasTerminalSource [0, 0, 0] = false := rfl

inductive MaterialXTerminalTarget where
  | shader | nodeGraph | missing | otherPrim | malformed
  deriving DecidableEq, Repr

def materialXTerminalTargetErrors (targets : List MaterialXTerminalTarget) : Nat :=
  (targets.filter fun target => target != .shader && target != .nodeGraph).length

def materialXTerminalTargetCountWarning (targets : Nat) : Bool :=
  decide (1 < targets)

def materialXUnknownPortCount (definitionPorts authoredPorts : List String) : Nat :=
  (authoredPorts.filter fun port => !definitionPorts.contains port).length

def materialXConnectionWarning (source input : Option String) : Bool :=
  match source, input with
  | some source, some input => source != input
  | _, _ => false

theorem identicalMaterialXPorts (type : String) :
    materialXConnectionWarning (some type) (some type) = false := by
  simp [materialXConnectionWarning]

def materialXConfig (usesMaterialX hasAPI isMaterial : Bool) : Diagnostic :=
  if (usesMaterialX && !hasAPI) || (hasAPI && !isMaterial) then .warning else .none

theorem materialXConfig_warns_iff (usesMaterialX hasAPI isMaterial : Bool) :
    materialXConfig usesMaterialX hasAPI isMaterial = .warning ↔
      (usesMaterialX = true ∧ hasAPI = false) ∨ (hasAPI = true ∧ isMaterial = false) := by
  cases usesMaterialX <;> cases hasAPI <;> cases isMaterial <;> decide

def volumeFieldTargetCount (count : Nat) : Diagnostic :=
  if 1 < count then .warning else .none

theorem volumeFieldTargetCount_warns_iff (count : Nat) :
    volumeFieldTargetCount count = .warning ↔ 1 < count := by
  by_cases h : 1 < count <;> simp [volumeFieldTargetCount, h]


/-- Invalid face counts are reported independently and contribute no indices
    to LightUSD's secondary size check. -/
def meshIndexCount (counts : List Int) : Nat :=
  (counts.map Int.toNat).sum

def meshIndexCountMatches (counts : Option (List Int)) (indices : Option (List Int)) : Bool :=
  match counts, indices with
  | some counts, some indices => meshIndexCount counts == indices.length
  | _, _ => true

def meshInvalidIndexCount (points : Option Nat) (indices : List Int) : Nat :=
  match points with
  | none => 0
  | some count => (indices.filter fun i => decide (i < 0 ∨ (count : Int) ≤ i)).length

theorem meshIndexCountMatches_iff (counts indices : List Int) :
    meshIndexCountMatches (some counts) (some indices) = true ↔
      meshIndexCount counts = indices.length := by
  simp [meshIndexCountMatches]

def subsetCoversDomain [BEq α] (domain members : List α) : Bool :=
  domain.all (fun element => members.contains element)

theorem subsetCoversDomain_iff [BEq α] [LawfulBEq α] (domain members : List α) :
    subsetCoversDomain domain members = true ↔ ∀ element ∈ domain, element ∈ members := by
  simp [subsetCoversDomain, List.all_eq_true]

inductive PointsArray where
  | ids | widths | normals | velocities | accelerations
  deriving DecidableEq, Repr

def pointsArraySizeValid (property : PointsArray) (points size : Nat)
    (interpolation : Option String := none) : Bool :=
  let interpolated := property == .widths || property == .normals
  if interpolated && interpolation == some "constant" then size == 1
  else size == points || (interpolated && interpolation.isNone && size == 1)

theorem idsSizeValid_iff (points size : Nat) :
    pointsArraySizeValid .ids points size = true ↔ size = points := by
  simp [pointsArraySizeValid]

def nurbsAxisErrors (vertices order : Int) (knotCount : Option Nat) (ordered : Bool) : Nat :=
  (if order ≤ 0 then 1 else 0) + (if vertices ≤ 0 ∨ vertices < order then 1 else 0) +
    (if vertices > 0 ∧ order > 0 ∧
      knotCount.any (fun n => n != (vertices + order).toNat) then 1 else 0) +
    (if knotCount.isSome && !ordered then 1 else 0)

def nurbsTrimArrayErrors (loopCounts orders vertices : List Nat)
    (ranges knots points : Nat) : Nat :=
  let curves := loopCounts.sum
  ([orders.length != curves, vertices.length != curves, ranges != curves,
    knots != vertices.sum + orders.sum, points != vertices.sum].filter id).length

theorem oneNurbsTrimCurveComplete :
    nurbsTrimArrayErrors [1] [2] [2] 1 4 2 = 0 := rfl

-- A coordinate of a unit-weight, clamped quadratic trim curve.
def quadraticTrimCoordinate (start middle finish t : Rat) : Rat :=
  (1-t)*(1-t)*start + 2*t*(1-t)*middle + t*t*finish

-- At an endpoint of a uniform, unclamped quadratic span, the two
-- adjacent homogeneous controls each contribute one half.
def uniformQuadraticEndpoint (first second : Rat × Rat × Rat) : Rat × Rat :=
  let weight := first.2.2 + second.2.2
  ((first.1 + second.1) / weight, (first.2.1 + second.2.1) / weight)

def trimLoopJoinWarnings (curves : List ((Rat × Rat) × (Rat × Rat))) : Nat :=
  let next := curves.drop 1 ++ curves.take 1
  ((curves.zip next).filter fun (current, successor) => current.2 != successor.1).length

def nurbsTrimOrderErrors (vertices orders : List Nat) : Nat :=
  if vertices.length = orders.length then
    ((vertices.zip orders).filter fun (count, order) => decide (count < order)).length
  else 0

def nurbsTrimKnotErrors (curves : List (List Rat)) : Nat :=
  (curves.filter fun knots =>
    !(knots.zip knots.tail).all (fun (a, b) => decide (a ≤ b))).length

def nurbsControlGridValid (u v points : Nat) : Bool :=
  u * v == points

theorem nurbsGridRejectsMissingControlPoint :
    nurbsControlGridValid 2 2 3 = false := rfl

def hermiteTangentCountValid (points tangents : Nat) : Bool :=
  points == tangents

inductive CurveBasis where
  | linear | bezier | bspline | catmullRom
  deriving DecidableEq, Repr

-- OpenUSD's reported count for positive linear vertex counts. This is
-- separate from the unresolved minimum renderable vertex count.
def linearBasisSegmentCount (periodic : Bool) (vertices : Nat) : Nat :=
  if periodic then vertices else vertices - 1

theorem twoLinearVerticesReportOneSegment :
    linearBasisSegmentCount false 2 = 1 := rfl

def cubicBasisCountValid (basis : CurveBasis) (wrap : String) (count : Nat) : Bool :=
  let step := if basis = .bezier then 3 else 1
  if wrap == "periodic" then count % step == 0
  else if wrap == "pinned" && basis != .bezier then count ≥ 2
  else count ≥ 4 && (count - 4) % step == 0

theorem pinnedBsplineWithTwoPoints : cubicBasisCountValid .bspline "pinned" 2 = true := rfl

/-- OpenUSD varying-data cardinality. Pinned curves use the nonperiodic
    authored-data count. Counts below four use the source-documented
    single-segment minimum of two values. OpenUSD 26.11's implementation
    can return fewer values for these short B-spline and Catmull-Rom curves. -/
def curveVaryingSize (basis : CurveBasis) (periodic : Bool) (counts : List Nat) : Nat :=
  (counts.map fun n =>
    match basis with
    | .linear => n + if periodic then 1 else 0
    | _ =>
      let step := if basis = .bezier then 3 else 1
      if periodic then n / step else (n - 4) / step + 2).sum

theorem curveVaryingSize_append (basis : CurveBasis) (periodic : Bool)
    (first second : List Nat) :
    curveVaryingSize basis periodic (first ++ second) =
      curveVaryingSize basis periodic first + curveVaryingSize basis periodic second := by
  simp [curveVaryingSize, List.sum_append]

def curveVaryingWidths (basis : CurveBasis) (periodic : Bool) (counts : List Nat)
    (widths : Nat) : Diagnostic :=
  if curveVaryingSize basis periodic counts = widths then .none else .error

inductive PrototypeOpinion where
  | absent | attribute | relationship (validTargets : List Bool)
  deriving DecidableEq, Repr

def prototypeCount : PrototypeOpinion → Nat
  | .relationship targets => targets.length
  | _ => 0

def prototypeErrors : PrototypeOpinion → Nat
  | .relationship [] => 1
  | .relationship targets => (targets.filter (!·)).length
  | _ => 1

/-- Authored orientations must have finite lanes and unit squared length,
    allowing for quantization in the authored precision. -/
def pointInstancerQuaternionValid (half : Bool) (lanes : Option (Rat × Rat × Rat × Rat)) :
    Bool :=
  match lanes with
  | none => false
  | some (w, x, y, z) =>
    let tolerance : Rat := if half then 1 / 500 else 1 / 100000
    decide (|w*w + x*x + y*y + z*z - 1| ≤ tolerance)

theorem pointInstancerQuaternionRejectsZero :
    pointInstancerQuaternionValid true (some (0, 0, 0, 0)) = false := by
  norm_num [pointInstancerQuaternionValid]

/-- A float orientation stream is selected once using its earliest sample,
    or its default when it has no samples. -/
def pointInstancerUsesFloatOrientations (defaultCount : Option Nat)
    (sampleCounts : List (Option Nat)) : Bool :=
  0 < ((sampleCounts.head?.getD defaultCount).getD 0)

theorem pointInstancerEmptyFirstFloatOrientationSample (defaultCount : Option Nat)
    (later : List (Option Nat)) :
    pointInstancerUsesFloatOrientations defaultCount (some 0 :: later) = false := rfl

theorem pointInstancerPrefersNonemptyFirstFloatOrientationSample :
    pointInstancerUsesFloatOrientations none [some 1, some 0] = true := by decide

/-- Each required array can be supplied by a default or at a numeric sample.
    A present empty array is a usable authored value. -/
def pointInstancerRequiredArrayErrors (arrays : List (List (Option Nat))) : Nat :=
  (arrays.filter fun opinions => !(opinions.any Option.isSome)).length

theorem pointInstancerEmptyRequiredArrays :
    pointInstancerRequiredArrayErrors [[some 0], [none, some 0]] = 0 := rfl

/-- An optional per-instance array must match positions at the same time. -/
def pointInstancerArrayErrors (positions values : Option Nat) : Nat :=
  match positions, values with
  | some n, some m => if n == m then 0 else 1
  | _, _ => 0

/-- Check the authored default indices against the relationship order and positions. -/
def pointInstancerIndexErrors (prototypes : PrototypeOpinion)
    (positions : Option Nat) (indices : Option (List Int)) : Nat :=
  match indices with
  | none => 0
  | some indices =>
    (if positions.isSome && positions != some indices.length then 1 else 0) +
      meshInvalidIndexCount (some (prototypeCount prototypes)) indices

theorem pointInstancerNoIndices (prototypes : PrototypeOpinion) (positions : Option Nat) :
    pointInstancerIndexErrors prototypes positions none = 0 := rfl

def indexedJoints (joints : List String) : List (String × Nat) :=
  joints.zipIdx.foldl (fun entries (joint, index) =>
    if jointPathValid joint && !(entries.any fun entry => entry.1 == joint) then
      entries ++ [(joint, index)]
    else entries) []

/-- Find the closest ancestor that is itself in the joint list. Its index can
    be later than the child's, which is diagnosed independently. -/
def nearestListedParent (table : List (String × Nat)) (joint : String) : Option Nat :=
  let components := joint.splitOn "/"
  (List.range (components.length - 1)).reverse.findSome? fun i =>
    let parent := String.intercalate "/" (components.take (i + 1))
    (table.find? (fun entry => entry.1 == parent)).map Prod.snd

def skeletonParentIndices (joints : List String) : List Int :=
  let table := indexedJoints joints
  table.map fun (joint, _) => (nearestListedParent table joint).map Int.ofNat |>.getD (-1)

def skeletonTopology (joints : List String) : Nat × Nat :=
  if joints.isEmpty then (0, 0)
  else
    let table := indexedJoints joints
    let parents := table.map fun (joint, child) => (nearestListedParent table joint, child)
    let roots := (parents.filter fun entry => entry.1.isNone).length
    let errors := (parents.filter fun (parent, child) =>
      parent.any (fun index => decide (child ≤ index))).length
    (errors, if roots == 1 then 0 else 1)

theorem skeletonTopology_nil : skeletonTopology [] = (0, 0) := rfl

def skeletonJointNameCount (joints names : Nat) : Diagnostic :=
  if 0 < joints ∧ names ≠ joints then .error else .none

inductive VersionOpinion where
  | absent | incompatible | string (version : String)
  deriving DecidableEq, Repr

/-- LightUSD reports unusual MaterialX version strings as a recommendation. -/
def materialXVersion : VersionOpinion → Diagnostic
  | .absent => .none
  | .incompatible => .error
  | .string version => if version.startsWith "1." then .none else .warning

inductive VolumeFieldOpinion where
  | attribute | blocked | targets (count : Nat)
  deriving DecidableEq, Repr

def volumeFieldRelationship : VolumeFieldOpinion → Diagnostic
  | .attribute => .error
  | .blocked => .none
  | .targets 0 => .warning
  | .targets (_ + 1) => .none

inductive FieldTargetType where
  | unknown | volumeField | other | nonPrimPath
  deriving DecidableEq, Repr

/-- A single forwarded prim path can still be absent or inactive on the composed stage. -/
def volumeFieldTargetMissing (count : Nat) (resolves : Bool) : Diagnostic :=
  if count == 1 && !resolves then .warning else .none

def volumeFieldTargetType (count : Nat) (type : FieldTargetType) : Diagnostic :=
  if count == 1 && (type == .other || type == .nonPrimPath) then .warning else .none

inductive JointLimitValue where
  | absent | invalid | negativeInfinity | positiveInfinity | finite (value : Rat)
  deriving DecidableEq, Repr

def nurbsRangeValid (knotBounds : Option (Rat × Rat)) : JointLimitValue → JointLimitValue → Bool
  | .finite low, .finite high =>
    decide (low < high) && knotBounds.all fun (first, last) =>
      decide (first ≤ low ∧ high ≤ last)
  | _, _ => false

-- These predicates model the LightUSD Camera diagnostics for typed opinions.
def cameraClippingValid : JointLimitValue → JointLimitValue → Bool
  | .finite near, .finite far => decide (0 ≤ near ∧ near < far)
  | _, _ => false

def cameraClippingErrors (opinions : List (Option (JointLimitValue × JointLimitValue))) : Nat :=
  (opinions.filter fun pair => pair.any fun (near, far) => !cameraClippingValid near far).length

def cameraShutterValid : JointLimitValue → JointLimitValue → Bool
  | .absent, _ | _, .absent => true
  | .finite opens, .finite closes => decide (opens ≤ closes)
  | _, _ => false

def cameraOpticValid (allowZero : Bool) : JointLimitValue → Bool
  | .absent => true
  | .finite value => if allowZero then decide (0 ≤ value) else decide (0 < value)
  | _ => false

theorem cameraClipping_rejects_equal (value : Rat) :
    cameraClippingValid (.finite value) (.finite value) = false := by
  simp [cameraClippingValid]

/-- The strict comparison used for each pair of extent coordinates.
    NaN is unordered. Infinity compares normally and is also diagnosed. -/
private def extentCoordinateReversed : JointLimitValue → JointLimitValue → Bool
  | .finite lo, .finite hi => decide (lo > hi)
  | .positiveInfinity, .finite _ => true
  | .positiveInfinity, .negativeInfinity => true
  | .finite _, .negativeInfinity => true
  | _, _ => false

abbrev ExtentPoint := JointLimitValue × JointLimitValue × JointLimitValue

/-- Errors in one extent opinion. Missing or blocked opinions supply no bounds. -/
def extentErrors (extent : Option (List ExtentPoint)) : Nat :=
  match extent with
  | none => 0
  | some [(lx, ly, lz), (hx, hy, hz)] =>
    let nonfinite := [lx, ly, lz, hx, hy, hz].any fun
      | .finite _ => false
      | _ => true
    let reversed := [(lx, hx), (ly, hy), (lz, hz)].any
      (fun (lo, hi) => extentCoordinateReversed lo hi)
    (if nonfinite then 1 else 0) + (if reversed then 1 else 0)
  | some _ => 1

theorem extentErrors_pointBounds (x y z : Rat) :
    extentErrors (some [(.finite x, .finite y, .finite z), (.finite x, .finite y, .finite z)]) = 0 := by
  simp [extentErrors, extentCoordinateReversed]

def pointWidthValid : JointLimitValue → Bool
  | .finite width => decide (0 ≤ width)
  | _ => false

def invalidPointWidths (widths : List JointLimitValue) : Nat :=
  (widths.filter (!pointWidthValid ·)).length

/-- Check the widths used as sphere diameters after primvar selection. -/
def pointsColliderWidthsValid (points : Nat) (widths : List JointLimitValue)
    (selectors : Option (List Int)) (groupSize : Nat) : Bool :=
  points > 0 && match selectors with
  | none => widths.length == points && widths.all pointWidthValid
  | some rows =>
      groupSize > 0 && rows.length * groupSize == points &&
        rows.all fun row =>
          0 ≤ row && (row.toNat + 1) * groupSize ≤ widths.length &&
            ((widths.drop (row.toNat * groupSize)).take groupSize).all pointWidthValid

theorem pointsColliderWidths_selectedGroup :
    pointsColliderWidthsValid 2 [.finite 2, .finite 4, .finite (-1), .finite 8]
      (some [0]) 2 = true ∧
    pointsColliderWidthsValid 2 [.finite 2, .finite 4, .finite (-1), .finite 8]
      (some [1]) 2 = false := by decide

/-- Signed unbounded sentinels are valid for the corresponding axis bounds.
    LightUSD retains its diagnostic for a reversed pair of finite limits. -/
def axisBoundValid (lower : Bool) : JointLimitValue → Bool
  | .absent | .finite _ => true
  | .negativeInfinity => lower
  | .positiveInfinity => !lower
  | .invalid => false

def axisOrderErrors : JointLimitValue → JointLimitValue → Nat
  | .finite lower, .finite upper => if lower > upper then 1 else 0
  | _, _ => 0

def axisLimitErrors (lower upper : JointLimitValue) : Nat :=
  (if axisBoundValid true lower then 0 else 1) +
    (if axisBoundValid false upper then 0 else 1) + axisOrderErrors lower upper

def coneLimitValid : JointLimitValue → Bool
  | .absent => true
  | .finite value => decide (value ≤ 180)
  | _ => false

def jointLimitErrors (lower upper cone0 cone1 : JointLimitValue) : Nat :=
  axisLimitErrors lower upper + (if coneLimitValid cone0 then 0 else 1) +
    (if coneLimitValid cone1 then 0 else 1)

def distanceLimitValid : JointLimitValue → Bool
  | .absent | .finite _ => true
  | _ => false

def distanceOrderErrors : JointLimitValue → JointLimitValue → Nat
  | .finite lower, .finite upper => if 0 ≤ upper ∧ upper < lower then 1 else 0
  | _, _ => 0

def distanceLimitErrors (lower upper : JointLimitValue) : Nat :=
  (if distanceLimitValid lower then 0 else 1) +
    (if distanceLimitValid upper then 0 else 1) + distanceOrderErrors lower upper

theorem unbounded_axis_limits :
    axisLimitErrors .negativeInfinity .positiveInfinity = 0 := by decide

theorem negative_upper_disables_distance_order (lower upper : Rat) (h : upper < 0) :
    distanceLimitErrors (.finite lower) (.finite upper) = 0 := by
  simp [distanceLimitErrors, distanceLimitValid, distanceOrderErrors, not_le.mpr h]


def sceneGravityValid : JointLimitValue → Bool
  | .absent | .negativeInfinity | .finite _ => true
  | _ => false

def sceneGravityErrors (magnitude : JointLimitValue) (directionValid : Bool) : Nat :=
  (if sceneGravityValid magnitude then 0 else 1) + (if directionValid then 0 else 1)

def physicalScalarValid (allowUnbounded : Bool) : JointLimitValue → Bool
  | .absent => true
  | .finite value => decide (0 ≤ value)
  | .positiveInfinity => allowUnbounded
  | _ => false

def driveValueValid (field : String) (value : JointLimitValue) : Bool :=
  if field = "targetPosition" ∨ field = "targetVelocity" then distanceLimitValid value
  else physicalScalarValid (field == "maxForce") value

/-- A triple -inf requests automatic computation. Mixed finite and infinite
    components cannot describe a center of mass. -/
def centerOfMassValid (x y z : JointLimitValue) : Bool :=
  (decide (x = .negativeInfinity ∧ y = .negativeInfinity ∧ z = .negativeInfinity)) ||
    match x, y, z with
    | .finite _, .finite _, .finite _ => true
    | _, _, _ => false

theorem automatic_center_of_mass :
    centerOfMassValid .negativeInfinity .negativeInfinity .negativeInfinity = true := by decide

end UsdSpec.Domains

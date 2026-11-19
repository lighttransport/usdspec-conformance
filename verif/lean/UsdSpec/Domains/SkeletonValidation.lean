import UsdSpec.Domains.Validation

namespace UsdSpec.Domains.SkeletonValidation

inductive ArrayOpinion where
  | absent | other | array (size : Nat)
  deriving DecidableEq, Repr

/-- Validate data at the default and at each authored, ordered finite sample.
    A value block contributes no array length. -/
def arrayCardinality (expected : Option Nat) (default : ArrayOpinion)
    (samples : List ArrayOpinion := []) : Nat × Nat :=
  match expected with
  | none => (0, 0)
  | some expected =>
    let mismatch := fun
      | .array count => count != expected
      | _ => false
    let defaultErrors := if mismatch default then 1 else 0
    (defaultErrors + (samples.filter mismatch).length,
      (samples.filter fun sample => decide (sample = .other)).length)

theorem cardinality_no_authoring (expected : Option Nat) :
    arrayCardinality expected .absent [] = (0, 0) := by
  cases expected <;> rfl

def animationJoints (hasJoints : Bool) : Diagnostic :=
  if hasJoints then .none else .warning

def skeletonTransforms (joints : Nat) (default : ArrayOpinion) : Diagnostic :=
  if joints = 0 then .none
  else match default with
    | .array count => if count = joints then .none else .error
    | _ => .warning

private def orderedUniqueNameErrors (names : List String) : Nat :=
  ((names.foldl (fun (seen, errors) name =>
    if name.isEmpty || seen.contains name then (seen, errors + 1)
    else (name :: seen, errors)) ([], 0)).2)

def animationBlendShapes (names : Option (List String)) (weightsAuthored : Bool)
    (default : ArrayOpinion) (samples : List ArrayOpinion := []) : Nat × Nat :=
  match names with
  | none => (0, if weightsAuthored then 1 else 0)
  | some names =>
    let (errors, warnings) := arrayCardinality (some names.length) default samples
    (orderedUniqueNameErrors names + errors, warnings)

def blendShapeOffsets : ArrayOpinion → Diagnostic
  | .array 0 => .warning
  | .array (_ + 1) => .none
  | _ => .error

def blendShapeIndices (offsets : Option Nat) (indices : List Int)
    (samples : List ArrayOpinion := []) : Nat × Nat :=
  let (errors, warnings) := arrayCardinality offsets (.array indices.length) samples
  let (_, negatives, duplicates) := indices.foldl (fun (seen, negatives, duplicates) index =>
    if index < 0 then (seen, negatives + 1, duplicates)
    else if seen.contains index then (seen, negatives, duplicates + 1)
    else (index :: seen, negatives, duplicates)) ([], 0, 0)
  (errors + negatives, warnings + duplicates)

def blendShapeInbetween (offsets : Option Nat) (validWeight : Bool)
    (values : ArrayOpinion) (samples : List ArrayOpinion := []) : Nat × Nat :=
  let (errors, warnings) := arrayCardinality offsets values samples
  (errors + (if validWeight then 0 else 1), warnings)

theorem invalid_weight_is_error (offsets : Option Nat) :
    blendShapeInbetween offsets false .absent [] = (1, 0) := by
  simp [blendShapeInbetween, cardinality_no_authoring]

def inheritedInfluence (localOpinion ancestorOpinion : Option α) : Option α :=
  localOpinion <|> ancestorOpinion

theorem inheritedInfluence_local (localValue : α) (ancestorOpinion : Option α) :
    inheritedInfluence (some localValue) ancestorOpinion = some localValue := rfl

def influenceInterpolationErrors (indices weights : Option String) : Nat :=
  let invalid := fun value => value != some "constant" && value != some "vertex"
  (if invalid indices then 1 else 0) + (if invalid weights then 1 else 0) +
    (if indices.isSome && weights.isSome && indices != weights then 1 else 0)

def influenceIndexErrors (localOrder skeletonOrder : Option Nat) (indices : List Int) : Nat :=
  (indices.filter fun index => decide (index < 0) ||
    ((localOrder <|> skeletonOrder).any fun count => decide ((count : Int) ≤ index))).length

theorem constantInfluencesAccepted : influenceInterpolationErrors (some "constant")
    (some "constant") = 0 := rfl

def influenceSizeErrors (indices weights indexSize weightSize : Nat) : Nat :=
  let incomplete := fun count size => size != 0 && count % size != 0
  (if indices != weights then 1 else 0) +
    (if incomplete indices indexSize || incomplete weights weightSize then 1 else 0)

def influenceSelectorErrors (tableGroups : Nat) (selectors : List Int) : Nat :=
  influenceIndexErrors (some tableGroups) none selectors

def resolvedInfluenceGroups (tableGroups : Nat) (selectors : Option (List Int)) : Option Nat :=
  match selectors with
  | none => some tableGroups
  | some indices =>
    if influenceSelectorErrors tableGroups indices = 0 then some indices.length else none

theorem emptyInfluenceSelectors (tableGroups : Nat) :
    resolvedInfluenceGroups tableGroups (some []) = some 0 := rfl

def selectedInfluenceRows (table : List α) (selectors : List Int) : List α :=
  (table.zipIdx.filter fun (_, index) => selectors.contains (Int.ofNat index)).map Prod.fst

theorem repeatedInfluenceSelector (value : α) :
    selectedInfluenceRows [value] [0, 0] = [value] := rfl

def influenceGroupCountValid (interpolation : String) (points : Option Nat)
    (indexGroups weightGroups : Nat) : Bool :=
  let expected := if interpolation == "constant" then some 1
    else if interpolation == "vertex" then points else none
  expected.all fun count => indexGroups == count && weightGroups == count

theorem constantInfluenceGroupCount (points : Option Nat) (indices weights : Nat) :
    influenceGroupCountValid "constant" points indices weights = true ↔
      indices = 1 ∧ weights = 1 := by
  simp [influenceGroupCountValid]

/-- Rational group sums model the normalization diagnostic away from the
    floating-point tolerance boundary. A missing member denotes a nonfinite value. -/
def influenceWeightGroup (weights : List (Option Rat)) : Diagnostic :=
  if weights.any Option.isNone then .error
  else
    let sum := (weights.filterMap id).sum
    if sum ≤ 0 ∨ 1 / 1000 < |sum - 1| then .warning else .none

theorem nonfiniteInfluenceWeight : influenceWeightGroup [none] = .error := rfl

-- One coordinate of linear blend skinning for translation-only joint matrices.
def blendTranslatedCoordinate (point : Rat) (influences : List (Rat × Rat)) : Rat :=
  (influences.map fun (weight, translation) => weight * (point + translation)).sum

theorem oneUnitTranslation (point translation : Rat) :
    blendTranslatedCoordinate point [(1, translation)] = point + translation := by
  simp [blendTranslatedCoordinate]

-- One coordinate when the linear part is diagonal, as for a half-turn
-- about a coordinate axis composed with axis-aligned scale.
def blendDiagonalCoordinate (point : Rat) (influences : List (Rat × Rat × Rat)) : Rat :=
  (influences.map fun (weight, coefficient, translation) =>
    weight * (coefficient * point + translation)).sum

theorem oneUnitDiagonal (point coefficient translation : Rat) :
    blendDiagonalCoordinate point [(1, coefficient, translation)] =
      coefficient * point + translation := by
  simp [blendDiagonalCoordinate]

-- One coordinate of a planar affine transform, blended across influences.
def blendPlanarCoordinate (point : Rat × Rat)
    (influences : List (Rat × Rat × Rat × Rat)) : Rat :=
  (influences.map fun (weight, xCoeff, yCoeff, shift) =>
    weight * (xCoeff * point.1 + yCoeff * point.2 + shift)).sum

def skinningMethodValid : TokenOpinion → Bool
  | .unauthored => true
  | .token value => value == "classicLinear" || value == "dualQuaternion"
  | .invalid => false

-- XY result for the unit X vector after blending identity and a Z half-turn
-- at zero translation, with the aligned real quaternion proportional to (w,0,0,z).
def dualQuaternionUnitX (w z : Rat) : Rat × Rat :=
  let normSquared := w*w + z*z
  ((w*w - z*z) / normSquared, 2*w*z / normSquared)

end UsdSpec.Domains.SkeletonValidation

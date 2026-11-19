import UsdSpec.Domains.Validation
import UsdSpec.Domains.UsdVol

namespace UsdSpec.Domains.VolumeValidation

def selectFieldGrid (grids : List (String × String)) (name : String)
    (index : Int) : Option (String × String) :=
  if index < 0 then none
  else (grids.filter (fun grid => name.isEmpty || grid.1 == name))[index.toNat]?

theorem negativeFieldIndex (grids : List (String × String)) (name : String) :
    selectFieldGrid grids name (-1) = none := rfl

def negativeFieldIndexCount (opinions : List (Option Int)) : Nat :=
  (opinions.filter fun value => value.any fun index => decide (index < 0)).length

theorem absentFieldIndexNoError : negativeFieldIndexCount [none] = 0 := rfl

def floatFieldTypeMatches (hint : String) (savedAsHalf : Bool) : Bool :=
  hint.isEmpty || hint == "float" || (savedAsHalf && hint == "half")

def effectiveFieldClass (file hint : String) : String :=
  if hint.isEmpty then file else hint

def fieldClassMismatch (file hint : String) : Bool :=
  !hint.isEmpty && file != "unknown" && file != hint

def rendersAsLevelSet (file hint : String) : Bool :=
  effectiveFieldClass file hint == "levelSet" && (file == "levelSet" || file == "unknown")

theorem fogFileCannotRenderAsLevelSet (hint : String) :
    rendersAsLevelSet "fogVolume" hint = false := by
  simp [rendersAsLevelSet]

-- Effective field paths after the immediate forwarding branches have resolved.
def forwardedFieldPaths (branches : List (List String)) : List String :=
  branches.flatten.eraseDups

theorem forwardedFieldPathsSharedTarget :
    forwardedFieldPaths [["/Field"], ["/Field"]] = ["/Field"] := rfl

def allowedTokens (schema property : String) : List String :=
  ((lookup UsdVol.catalog schema).bind (fun spec => findProperty spec property))
    |>.map Property.allowedTokens |>.getD []

def tokenAllowed (allowed : List String) : TokenOpinion → Bool
  | .unauthored => true
  | .invalid => false
  | .token token => allowed.contains token

/-- One finding per property, even when several authored samples disagree. -/
def tokenProperty (schema property : String) (default : TokenOpinion)
    (samples : List TokenOpinion := []) : Diagnostic :=
  let allowed := allowedTokens schema property
  if tokenAllowed allowed default && samples.all (tokenAllowed allowed) then .none else .error

def fieldAssetDataType (schema : String) (hasValue : Bool) (default : TokenOpinion)
    (samples : List TokenOpinion := []) : Nat × Nat :=
  (if tokenProperty schema "fieldDataType" default samples = .error then 1 else 0,
   if hasValue then 0 else 1)

/-- The sample count includes only nonempty asset paths. -/
def fieldAssetFilePath (hasAttribute : Bool) (path : Option String) (samples : Nat) :
    Diagnostic :=
  if hasAttribute && (0 < samples || path.any (fun value => !value.isEmpty))
  then .none else .warning

theorem sample_only_file_path (samples : Nat) (hasSamples : 0 < samples) :
    fieldAssetFilePath true none samples = .none := by
  simp [fieldAssetFilePath, hasSamples]

/-- Prefer float positions when both representations have authored values. -/
def particleCount (full half : Option Nat) : Option Nat :=
  full.or half

def particleArraySize (particles : Option Nat) (values : Nat) : Diagnostic :=
  if particles.any (· != values) then .warning else .none

def particleProvider (gaussian hasProvider : Bool) : Diagnostic :=
  if gaussian || hasProvider then .none else .warning

def sphericalHarmonicsDegree (particles : Option Nat) (degree : Int) : Diagnostic :=
  if particles.isSome && degree < 0 then .warning else .none

/-- Exact mathematical count, independent of the implementation's size_t. -/
def sphericalHarmonicsCount (particles : Nat) (degree : Int) : Option Nat :=
  if degree < 0 then none else some (particles * (degree.toNat + 1)^2)

def sphericalHarmonicsSize (particles : Option Nat) (degree : Int)
    (coefficients : Nat) : Diagnostic :=
  if (particles.bind (sphericalHarmonicsCount · degree)).any (· != coefficients)
  then .warning else .none

theorem sphericalHarmonics_zero (particles : Nat) :
    sphericalHarmonicsCount particles 0 = some particles := by
  simp [sphericalHarmonicsCount]

theorem sphericalHarmonics_empty (degree : Int) (valid : 0 ≤ degree) :
    sphericalHarmonicsCount 0 degree = some 0 := by
  simp [sphericalHarmonicsCount, not_lt.mpr valid]

end UsdSpec.Domains.VolumeValidation

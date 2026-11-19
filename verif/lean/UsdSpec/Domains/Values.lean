import UsdSpec.Domains.Catalog
import UsdSpec.LayerOffset
import UsdSpec.ValueResolution.Metadata

namespace UsdSpec.Domains

/-- Authored values for parser and writer witnesses. These use exact small
integers even in floating-point values, so comparisons don't depend on
decimal-to-binary rounding or an oracle's formatting precision. -/
structure ValueWitness where
  weak : String
  strong : String
  deriving DecidableEq, Repr

def ValueWitness.resolved (value : ValueWitness) (override : Bool) : String :=
  (ValueResolution.Metadata.strongest
    [if override then some value.strong else none, some value.weak]).getD value.weak

theorem ValueWitness.resolved_weak (value : ValueWitness) :
    value.resolved false = value.weak := rfl

theorem ValueWitness.resolved_strong (value : ValueWitness) :
    value.resolved true = value.strong := rfl

abbrev SampleMap := List (ℚ × String)

def offsetSamples (offset : LayerOffset) (samples : SampleMap) : SampleMap :=
  samples.map fun (time, value) => (offset.apply time, value)

theorem offsetSamples_compose (outer inner : LayerOffset) (samples : SampleMap) :
    offsetSamples (outer.compose inner) samples =
      offsetSamples outer (offsetSamples inner samples) := by
  simp [offsetSamples, List.map_map, Function.comp_def, LayerOffset.apply_compose]

def composeSamples (weak : SampleMap) (strong : Option SampleMap)
    (offset : LayerOffset) : SampleMap :=
  (ValueResolution.Metadata.strongest [strong, some (offsetSamples offset weak)]).getD []

theorem composeSamples_strong (weak strong : SampleMap) (offset : LayerOffset) :
    composeSamples weak (some strong) offset = strong := rfl

theorem composeSamples_weak (weak : SampleMap) (offset : LayerOffset) :
    composeSamples weak none offset = offsetSamples offset weak := rfl

private def tokenWitness (allowed : List String) : ValueWitness :=
  match allowed with
  | [] => ⟨"\"weak:token\"", "\"strong:token\""⟩
  | first :: rest => ⟨reprStr first, reprStr (rest.getLast?.getD first)⟩

private def scalarWitness (scalar : String) (allowed : List String) : Option ValueWitness :=
  match scalar with
  | "token" => some (tokenWitness allowed)
  | "bool" => some ⟨"false", "true"⟩
  | "int" | "int64" | "float" | "double" | "half" => some ⟨"2", "7"⟩
  | "asset" => some ⟨"@weak.bin@", "@strong.bin@"⟩
  | "string" => some ⟨"\"weak value\"", "\"strong value\""⟩
  | "float2" | "double2" => some ⟨"(1,2)", "(4,3)"⟩
  | "float3" | "point3f" | "point3h" | "vector3f" | "normal3f" | "color3f"
  | "double3" | "int3" | "half3" => some ⟨"(1,2,3)", "(6,5,4)"⟩
  | "float4" | "int4" => some ⟨"(1,2,3,4)", "(8,7,6,5)"⟩
  | "quatf" | "quath" => some ⟨"(1,0,0,0)", "(0,1,0,0)"⟩
  | "matrix4d" => some ⟨"((1,0,0,0),(0,1,0,0),(0,0,1,0),(1,2,3,1))",
                       "((1,0,0,0),(0,1,0,0),(0,0,1,0),(6,5,4,1))"⟩
  | _ => none

def authoredValueWitness (property : Property) : Option ValueWitness :=
  match property.kind with
  | .relationship => some ⟨"</WeakTarget>", "</StrongTarget>"⟩
  | .attribute =>
    if property.valueType.endsWith "[]" then
      (scalarWitness (property.valueType.dropEnd 2).toString property.allowedTokens).map
        fun value => ⟨"[" ++ value.weak ++ "]", "[" ++ value.strong ++ ", " ++ value.weak ++ "]"⟩
    else scalarWitness property.valueType property.allowedTokens

/-- A relationship without target opinions is authored as a declaration.
    A witness supplies two alternative target opinions for format replay. -/
theorem relationshipWitness (property : Property) (h : property.kind = .relationship) :
    authoredValueWitness property = some ⟨"</WeakTarget>", "</StrongTarget>"⟩ := by
  simp [authoredValueWitness, h]

end UsdSpec.Domains

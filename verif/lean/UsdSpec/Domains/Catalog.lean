namespace UsdSpec.Domains

inductive PropertyKind where
  | attribute
  | relationship
  deriving DecidableEq, Repr

structure Property where
  name : String
  kind : PropertyKind
  valueType : String
  variability : String
  allowedTokens : List String
  /-- The fallback as a USDA value literal for the declared value type. -/
  fallback : Option String
  deriving DecidableEq, Repr

structure Schema where
  identifier : String
  kind : String
  parents : List String
  builtInAPIs : List String
  canOnlyApplyTo : List String
  properties : List Property
  deriving DecidableEq, Repr

def lookup (catalog : List Schema) (identifier : String) : Option Schema :=
  catalog.find? (fun schema => schema.identifier == identifier)

theorem lookup_exists_iff (catalog : List Schema) (identifier : String) :
    (lookup catalog identifier).isSome ↔
      ∃ schema ∈ catalog, schema.identifier = identifier := by
  simp [lookup, List.isSome_find?]

def findProperty (schema : Schema) (name : String) : Option Property :=
  schema.properties.find? (fun property => property.name == name)

theorem findProperty_exists_iff (schema : Schema) (name : String) :
    (findProperty schema name).isSome ↔
      ∃ property ∈ schema.properties, property.name = name := by
  simp [findProperty, List.isSome_find?]

def inheritedProperty (catalog : List Schema) (schema : Schema) (name : String) :
    Option Property :=
  schema.parents.head?.bind (fun parent =>
    (lookup catalog parent).bind (fun base => findProperty base name))

/-- The generated schema layers expand inherited declarations. Store the
    local differences, and let the runtime registry follow the parent. -/
def localProperties (catalog : List Schema) (schema : Schema) : List Property :=
  schema.properties.filter fun prop =>
    decide (inheritedProperty catalog schema prop.name ≠ some prop)

theorem mem_localProperties (catalog : List Schema) (schema : Schema) (prop : Property) :
    prop ∈ localProperties catalog schema ↔
      prop ∈ schema.properties ∧ inheritedProperty catalog schema prop.name ≠ some prop := by
  simp [localProperties]

theorem omitted_is_inherited (catalog : List Schema) (schema : Schema) (prop : Property)
    (has : prop ∈ schema.properties) (omitted : prop ∉ localProperties catalog schema) :
    inheritedProperty catalog schema prop.name = some prop := by
  by_cases inherited : inheritedProperty catalog schema prop.name = some prop
  · exact inherited
  · exact False.elim (omitted ((mem_localProperties catalog schema prop).mpr ⟨has, inherited⟩))

/-- Expand declared built-ins in preorder. The catalog size bounds a path
    through the catalog graph, and fuel terminates even a malformed cycle. -/
def expandBuiltinAPIs (catalog : List Schema) : Nat → String → List String
  | 0, _ => []
  | fuel + 1, schema =>
    let direct := (lookup catalog schema).map (·.builtInAPIs) |>.getD []
    direct.flatMap (fun api => api :: expandBuiltinAPIs catalog fuel api)

theorem expandBuiltinAPIs_zero (catalog : List Schema) (schema : String) :
    expandBuiltinAPIs catalog 0 schema = [] := rfl

structure SchemaContribution where
  schema : Schema
  instanceName : Option String := none

def matchProperty (contribution : SchemaContribution) (name : String) : Option Property :=
  match contribution.instanceName with
  | none => findProperty contribution.schema name
  | some instanceName =>
    (contribution.schema.properties.find? (fun property =>
      property.name.replace "__INSTANCE_NAME__" instanceName == name)).map
      (fun property => { property with name })

/-- Consult effective schema contributions in precedence order. The caller
    supplies the resolved typed contribution, then built-in and authored APIs. -/
def effectiveProperty (contributions : List SchemaContribution) (name : String) :
    Option Property :=
  contributions.findSome? (fun contribution => matchProperty contribution name)

theorem effectiveProperty_eq_first (contributions : List SchemaContribution) (name : String) :
    effectiveProperty contributions name =
      (contributions.filterMap (fun contribution => matchProperty contribution name)).head? := by
  simp [effectiveProperty]

end UsdSpec.Domains

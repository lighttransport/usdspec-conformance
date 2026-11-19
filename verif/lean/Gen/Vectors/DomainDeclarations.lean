import UsdSpec.Domains.UsdGeom
import UsdSpec.Domains.UsdSkel
import UsdSpec.Domains.UsdPhysics
import UsdSpec.Domains.UsdMtlx
import UsdSpec.Domains.UsdVol
import UsdSpec.Domains.UsdShade
import UsdSpec.Domains.UsdLux
import UsdSpec.Domains.UsdRender
import UsdSpec.Domains.UsdMedia
import UsdSpec.Domains.UsdUI
import UsdSpec.Domains.UsdHydra
import UsdSpec.Domains.UsdProc
import UsdSpec.Domains.UsdRi
import UsdSpec.Domains.UsdSemantics
import UsdSpec.Domains.UsdLod
import UsdSpec.Domains.UsdProfiles
import UsdSpec.Domains.Values
import Lean.Data.Json

namespace Gen.DomainDeclarations
open Lean UsdSpec UsdSpec.Domains

def sampleDictionary (samples : SampleMap) : String :=
  "{" ++ String.intercalate ", " (samples.map fun (time, value) =>
    toString time ++ ": " ++ value) ++ "}"

def sampleOffset : LayerOffset := ⟨4, 2⟩

def sampleJson (value : ValueWitness) (override : Bool) : Json :=
  let shadow := if override then value.strong else "None"
  let weak : SampleMap := [(1, value.weak), (3, value.strong)]
  let strong : Option SampleMap := if override then some [(7, value.strong)] else none
  Json.mkObj [
    ("weak", toJson (sampleDictionary weak)),
    ("strongDefault", toJson shadow),
    ("samplesOverDefault", toJson (sampleDictionary [(7, value.strong), (9, "None")])),
    ("strong", toJson (strong.map sampleDictionary)),
    ("resolved", toJson (sampleDictionary (composeSamples weak strong sampleOffset)))]

def propertyJson (instanceName : Option String) (property : Property) (index : Nat) : Json :=
  let name := instanceName.map (property.name.replace "__INSTANCE_NAME__") |>.getD property.name
  let value := authoredValueWitness property
  let override := index % 2 == 0
  let varying := property.kind == .attribute && property.variability == "Sdf.VariabilityVarying"
  Json.mkObj [
    ("samples", if varying then toJson (value.map (sampleJson · override)) else Json.null),
    ("fallback", toJson property.fallback),
    ("weakValue", toJson (value.map ValueWitness.weak)),
    ("strongValue", toJson (if override then value.map ValueWitness.strong else none)),
    ("resolvedValue", toJson (value.map (·.resolved override))),
    ("name", toJson name), ("type", toJson property.valueType),
    ("relationship", toJson (decide (property.kind = .relationship))),
    ("uniform", toJson (property.variability == "Sdf.VariabilityUniform"))]

def schemaJson (catalog : List Schema) (schema : Schema) : Json :=
  let instanceName := if schema.kind == "multipleApplyAPI" then some "conformance" else none
  Json.mkObj [
    ("name", toJson schema.identifier), ("kind", toJson schema.kind),
    ("builtInAPIs", toJson ((expandBuiltinAPIs catalog catalog.length schema.identifier).eraseDups)),
    ("canOnlyApplyTo", toJson schema.canOnlyApplyTo), ("instance", toJson instanceName),
    ("properties", toJson (schema.properties.zipIdx.map (fun (property, index) => propertyJson instanceName property index)))]

private def macroRow (macroName : String) (arguments : List String) : String :=
  macroName ++ "(" ++ String.intercalate ", " arguments ++ ")"

def runtimeProbeRows (catalog : List Schema) (schema : Schema) : List String :=
  let (primType, applied, instanceName) :=
    if schema.kind == "concreteTyped" then (schema.identifier, "", none)
    else if schema.kind == "singleApplyAPI" then ("", schema.identifier, none)
    else if schema.kind == "multipleApplyAPI" then
      ("", schema.identifier ++ ":conformance", some "conformance")
    else ("", "", none)
  let parent := schema.parents.head?.getD ""
  let schemaRow := macroRow "LIGHTUSD_REGISTRY_KIND"
    ([schema.identifier, schema.kind, parent].map reprStr)
  let builtins := expandBuiltinAPIs catalog catalog.length schema.identifier
  let builtinRows := builtins.eraseDups.map fun api =>
    macroRow "LIGHTUSD_REGISTRY_BUILTIN" ([schema.identifier, schema.kind, api].map reprStr)
  schemaRow :: builtinRows ++ if primType.isEmpty && applied.isEmpty then [] else
    schema.properties.map fun property =>
      let name := instanceName.map (property.name.replace "__INSTANCE_NAME__") |>.getD property.name
      let type := if property.kind == .relationship then "relationship" else property.valueType
      let fields := [reprStr primType, reprStr applied, reprStr name, reprStr type,
        property.fallback.map reprStr |>.getD "nullptr"]
      macroRow "LIGHTUSD_REGISTRY_PROBE" fields

def registryRows (catalog : List Schema) (schema : Schema) : List String :=
  let parent := schema.parents.head?.getD ""
  let schemaRow := macroRow "LIGHTUSD_DOMAIN_SCHEMA"
    ([schema.identifier, parent].map reprStr)
  let builtinRows := schema.builtInAPIs.map fun api =>
    macroRow "LIGHTUSD_DOMAIN_BUILTIN" ([schema.identifier, api].map reprStr)
  let kindRow := macroRow "LIGHTUSD_DOMAIN_KIND" ([schema.identifier, schema.kind].map reprStr)
  schemaRow :: kindRow :: builtinRows ++ ((localProperties catalog schema).map fun prop =>
    let name := prop.name.replace "__INSTANCE_NAME__" "__INSTANCE__"
    let typeName := if prop.kind == .relationship then "relationship" else prop.valueType
    macroRow "LIGHTUSD_DOMAIN_PROPERTY" (([schema.identifier, name, typeName].map reprStr) ++
      [prop.fallback.map reprStr |>.getD "nullptr"]))

def files : List (String × String) :=
  let schemas := UsdGeom.catalog ++ UsdSkel.catalog ++ UsdPhysics.catalog ++
    UsdMtlx.catalog ++ UsdVol.catalog ++ UsdShade.catalog ++ UsdLux.catalog ++
    UsdRender.catalog ++ UsdMedia.catalog ++ UsdUI.catalog ++ UsdHydra.catalog ++ UsdProc.catalog ++ UsdRi.catalog ++ UsdSemantics.catalog ++ UsdLod.catalog ++ UsdProfiles.catalog
  let matrix := Json.mkObj [
    ("schemas", toJson (schemas.map (schemaJson schemas))),
    ("sampleSublayer", toJson
      s!"@weak.usda@ (offset = {sampleOffset.offset}; scale = {sampleOffset.scale})")]
  [("domain-declaration-vectors.json", matrix.pretty ++ "\n"),
   ("domain-registry-vectors.inc", "// Generated by usdspec-gen (Gen.Vectors.DomainDeclarations).\n" ++
      String.intercalate "\n" (schemas.flatMap (runtimeProbeRows schemas)) ++ "\n"),
   ("openusd-domain-schema-registry.inc",
      "// Generated by usdspec-gen from the OpenUSD v26.11.0 domain catalogs.\n" ++
      String.intercalate "\n" (schemas.flatMap (registryRows schemas)) ++ "\n")]

end Gen.DomainDeclarations

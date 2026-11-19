import UsdSpec.ValueResolution.Metadata
import UsdSpec.Composition.NamespaceMap
import UsdSpec.ListOp
import Lean.Data.Json

namespace Gen.DomainRoundtrip
open Lean UsdSpec.ValueResolution.Metadata

structure Opinion where
  declaration : String
  weak : String
  strong : Option String := none

def Opinion.resolved (opinion : Opinion) : String :=
  (strongest [opinion.strong, some opinion.weak]).getD opinion.weak

theorem Opinion.resolved_strong (declaration weak strong : String) :
    (Opinion.mk declaration weak (some strong)).resolved = strong := rfl

theorem Opinion.resolved_weak (declaration weak : String) :
    (Opinion.mk declaration weak none).resolved = weak := rfl

def Opinion.render (opinion : Opinion) (value : String) : String :=
  "    " ++ opinion.declaration ++ " = " ++ value ++ "\n"

def Opinion.renderComposed (opinion : Opinion) : String :=
  if opinion.declaration.startsWith "rel " && opinion.resolved == "None" then
    "    " ++ opinion.declaration ++ "\n"
  else opinion.render opinion.resolved

structure Fixture where
  id : String
  schema : String
  api : String := ""
  opinions : List Opinion
  supportingPrims : String := ""

def fixturePrim (fixture : Fixture) (body : String) (flattened : Bool)
    (specifier : String := "def") (name : String := "Subject") : String :=
  specifier ++ " " ++ fixture.schema ++ " " ++ reprStr name ++
    (if fixture.api.isEmpty then "" else
       (if flattened then " (apiSchemas = [" else " (prepend apiSchemas = [") ++
         reprStr fixture.api ++ "])") ++
    " {\n" ++ body ++ "}\n"

def fixtureTarget (source destination : String) (value : String) : String :=
  if value.startsWith "</" && value.endsWith ">" then
    let path := ((value.drop 2).dropEnd 1).toString.splitOn "/"
    match UsdSpec.NamespaceMap.mapChecked [([source], [destination])] (source :: path) with
    | some mapped => "</" ++ String.intercalate "/" mapped ++ ">"
    | none => "None"
  else value

def envelope (name metadata contents : String) : String :=
  "def Xform " ++ reprStr name ++ metadata ++ " {\n" ++ contents ++ "}\n"

inductive FixtureArc where
  | sublayer | reference | payload
  deriving DecidableEq

def renderCase (fixture : Fixture) (arc : FixtureArc) : Json :=
  let header := "#usda 1.0\n"
  let remap := arc != .sublayer
  let toSource := if remap then fixtureTarget "Source" "Source" else id
  let toDestination := if remap then fixtureTarget "Source" "World" else id
  let weak := String.join (fixture.opinions.map fun o => o.render (toSource o.weak))
  let strong := String.join (fixture.opinions.filterMap fun o =>
    o.strong.map (fun value => o.render (toDestination value)))
  let resolved := String.join (fixture.opinions.map fun o =>
    ({ o with weak := toDestination o.weak, strong := o.strong.map toDestination }).renderComposed)
  let source := fixturePrim fixture weak false ++ fixture.supportingPrims
  let subject := "over \"Subject\" {\n" ++ strong ++ "}\n"
  let composed := fixturePrim fixture resolved true ++ fixture.supportingPrims
  let (suffix, root) := match arc with
    | .sublayer => ("", "(subLayers = [@weak.usda@])\n" ++ subject)
    | .reference =>
      ("-reference", envelope "World" " (prepend references = @weak.usda@</Source>)" subject)
    | .payload =>
      ("-payload", envelope "World" " (prepend payload = @weak.usda@</Source>)" subject)
  Json.mkObj <| [
    ("id", toJson (fixture.id ++ suffix)),
    ("weak", toJson (header ++ if remap then envelope "Source" "" source else source)),
    ("root", toJson (header ++ root)),
    ("composed", toJson (header ++ if remap then envelope "World" "" composed else composed))] ++
    (if arc == .payload then
      let localOpinions := String.join (fixture.opinions.filterMap fun o =>
        o.strong.map fun value => ({ o with strong := some (toDestination value) }).renderComposed)
      [("deferred", toJson (header ++ envelope "World" "" ("over \"Subject\" {\n" ++ localOpinions ++ "}\n")))]
     else [])

def renderVariant (fixture : Fixture) (selectAlternate : Bool) : Json :=
  let header := "#usda 1.0\n"
  let selection := if selectAlternate then "alternate" else "base"
  let mapTarget := fixtureTarget "World" "World"
  let branch (alternate : Bool) (flattened : Bool) :=
    let body := String.join (fixture.opinions.map fun o =>
      let opinion := Opinion.mk o.declaration (mapTarget o.weak)
        (if alternate then o.strong.map mapTarget else none)
      if flattened then opinion.renderComposed else opinion.render opinion.resolved)
    fixturePrim fixture body flattened ++ fixture.supportingPrims
  let variants := "variantSet \"detail\" = {\n\"base\" {\n" ++ branch false false ++
    "}\n\"alternate\" {\n" ++ branch true false ++ "}\n}\n"
  let weak := envelope "World" " (prepend variantSets = \"detail\")"
    variants
  let root := "(subLayers = [@weak.usda@])\nover \"World\" (variants = { string detail = " ++
    reprStr selection ++ " }) {\n}\n"
  let composed := envelope "World" "" (branch selectAlternate true)
  Json.mkObj [("id", toJson (fixture.id ++ "-variant-" ++ selection)),
    ("weak", toJson (header ++ weak)), ("root", toJson (header ++ root)),
    ("composed", toJson (header ++ composed))]

def renderClassArc (fixture : Fixture) (specializes : Bool) : Json :=
  let header := "#usda 1.0\n"
  let arc := if specializes then "specializes" else "inherits"
  let weakBody := String.join (fixture.opinions.map fun o => o.render o.weak)
  let localBody := String.join (fixture.opinions.filterMap fun o => o.strong.map o.render)
  let template := fixturePrim fixture weakBody true "class" "Template"
  let weak := template ++ fixture.supportingPrims
  let root := "(subLayers = [@weak.usda@])\ndef " ++ fixture.schema ++
    " \"Subject\" (prepend " ++ arc ++ " = </Template>) {\n" ++ localBody ++ "}\n"
  let composed := weak ++ fixturePrim fixture
    (String.join (fixture.opinions.map Opinion.renderComposed)) true
  Json.mkObj [("id", toJson (fixture.id ++ "-" ++ arc)),
    ("weak", toJson (header ++ weak)), ("root", toJson (header ++ root)),
    ("composed", toJson (header ++ composed))]

def fixtures : List Fixture := [
  { id := "geom-mesh", schema := "Mesh", opinions := [
      ⟨"point3f[] points", "[(0,0,0), (1,0,0), (0,1,0)]", none⟩,
      ⟨"int[] faceVertexCounts", "[3]", none⟩,
      ⟨"int[] faceVertexIndices", "[0,1,2]", some "[2,1,0]"⟩,
      ⟨"uniform token subdivisionScheme", "\"catmullClark\"", some "\"none\""⟩] },
  { id := "skel-skeleton", schema := "Skeleton", api := "SkelBindingAPI", opinions := [
      ⟨"uniform token[] joints", "[\"root\", \"root/child\"]", none⟩,
      ⟨"uniform matrix4d[] bindTransforms",
        "[((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1)), ((1,0,0,0),(0,1,0,0),(0,0,1,0),(1,0,0,1))]", none⟩,
      ⟨"rel skel:animationSource", "</Walk>", some "</Run>"⟩],
    supportingPrims := "def SkelAnimation \"Walk\" {}\ndef SkelAnimation \"Run\" {}\n" },
  { id := "skel-blend-shape", schema := "BlendShape", opinions := [
      ⟨"uniform vector3f[] offsets", "[(0,0,0),(1,0,0)]", none⟩,
      ⟨"uniform int[] pointIndices", "[1,3]", none⟩,
      ⟨"uniform point3f[] inbetweens:half", "[(0,0,0),(0.5,0,0)] (weight = 0.5)", none⟩,
      ⟨"vector3f[] inbetweens:half:normalOffsets", "[(0,0,0),(0,0.5,0)]",
        some "[(0,0,0),(0,0.25,0)]"⟩] },
  { id := "physics-drive", schema := "PhysicsRevoluteJoint", api := "PhysicsDriveAPI:angular",
    opinions := [
      ⟨"uniform token physics:axis", "\"X\"", some "\"Z\""⟩,
      ⟨"float drive:angular:physics:stiffness", "5", some "8"⟩,
      ⟨"rel physics:body0", "</Body>", none⟩,
      ⟨"rel physics:body1", "</Body>", some "None"⟩],
    supportingPrims := "def Xform \"Body\" (apiSchemas = [\"PhysicsRigidBodyAPI\"]) {}\n" },
  { id := "mtlx-config", schema := "Material", api := "MaterialXConfigAPI", opinions := [
      ⟨"string config:mtlx:version", "\"1.38\"", some "\"1.39\""⟩,
      ⟨"token outputs:mtlx:surface.connect", "</Shader.outputs:out>", none⟩],
    supportingPrims := "def Shader \"Shader\" {\n    uniform token info:id = \"ND_standard_surface_surfaceshader\"\n    token outputs:out\n}\n" },
  { id := "vol-openvdb", schema := "Volume", opinions := [
      ⟨"rel field:density", "</OldField>", some "</Field>"⟩],
    supportingPrims := "def OpenVDBAsset \"OldField\" {\n    token fieldName = \"oldDensity\"\n    asset filePath = @old.vdb@\n}\ndef OpenVDBAsset \"Field\" {\n    token fieldName = \"density\"\n    asset filePath = @smoke.vdb@\n}\n" }]

def blockFixtures : List Fixture := [
  { id := "geom-block", schema := "Mesh", opinions := [
      ⟨"point3f[] points", "[(0,0,0),(1,0,0),(0,1,0)]", some "None"⟩,
      ⟨"uniform token subdivisionScheme", "\"none\"", some "None"⟩] },
  { id := "skel-block", schema := "SkelAnimation", opinions := [
      ⟨"uniform token[] joints", "[\"root\"]", some "None"⟩,
      ⟨"float3[] translations", "[(0,0,0)]", some "None"⟩] },
  { id := "physics-block", schema := "PhysicsRevoluteJoint", api := "PhysicsDriveAPI:angular",
    opinions := [⟨"uniform token physics:axis", "\"Z\"", some "None"⟩,
      ⟨"float drive:angular:physics:stiffness", "8", some "None"⟩] },
  { id := "mtlx-block", schema := "Material", api := "MaterialXConfigAPI",
    opinions := [⟨"string config:mtlx:version", "\"1.39\"", some "None"⟩] },
  { id := "vol-block", schema := "Volume",
    opinions := [⟨"rel field:density", "</Field>", some "None"⟩],
    supportingPrims := "def OpenVDBAsset \"Field\" {\n    asset filePath = @smoke.vdb@\n}\n" },
  { id := "vol-field-block", schema := "OpenVDBAsset",
    opinions := [⟨"asset filePath", "@smoke.vdb@", some "None"⟩] }]

private def apiList (apis : List String) : String :=
  if apis.isEmpty then "None"
  else "[" ++ String.intercalate ", " (apis.map reprStr) ++ "]"

def renderApiEdits (fixture : Fixture) (clear : Bool) : Json :=
  let header := "#usda 1.0\n"
  let removed := "CollectionAPI:old"
  let retained := if fixture.api.isEmpty then "CollectionAPI:retained" else fixture.api
  let weakApis := [removed, retained]
  let edits : UsdSpec.Composable String :=
    ⟨[removed], ["CollectionAPI:first"], ["CollectionAPI:last"]⟩
  let op : UsdSpec.ListOp String := if clear then .explicit [] else .comp edits
  let applied := UsdSpec.ListOp.apply op weakApis
  let authored := if clear then "apiSchemas = None"
    else "delete apiSchemas = " ++ apiList edits.deleted ++
      "\nprepend apiSchemas = " ++ apiList edits.prepended ++
      "\nappend apiSchemas = " ++ apiList edits.appended
  let body := String.join (fixture.opinions.map fun o => o.render o.weak)
  let prim := fun apis => "def " ++ fixture.schema ++ " \"Subject\" (\napiSchemas = " ++
    apiList apis ++ "\n) {\n" ++ body ++ "}\n" ++ fixture.supportingPrims
  let root := "(subLayers = [@weak.usda@])\nover \"Subject\" (\n" ++ authored ++ "\n) {\n}\n"
  Json.mkObj [("id", toJson (fixture.id ++ if clear then "-api-clear" else "-api-edits")),
    ("weak", toJson (header ++ prim weakApis)), ("root", toJson (header ++ root)),
    ("composed", toJson (header ++ prim applied))]

private def pathList (paths : List String) : String :=
  "[" ++ String.intercalate ", " (paths.map fun path => "<" ++ path ++ ">") ++ "]"

def renderTargetEdits (family schema property targetType api : String) : Json :=
  let header := "#usda 1.0\n"
  let connection := property.endsWith ".connect"
  let target := fun name => "/" ++ name ++ if connection then ".outputs:out" else ""
  let weakPaths := [target "Old", target "Retained"]
  let edits : UsdSpec.Composable String :=
    ⟨[target "Old"], [target "First"], [target "Last"]⟩
  let applied := UsdSpec.ListOp.apply (.comp edits) weakPaths
  let supporting := String.join (["Old", "Retained", "First", "Last"].map fun name =>
    "def " ++ targetType ++ " " ++ reprStr name ++
      (if connection then " {\n    token outputs:out\n}\n" else " {}\n"))
  let fixture : Fixture := ⟨family, schema, api, [], supporting⟩
  let prim := fun paths flattened =>
    fixturePrim fixture ("    " ++ property ++ " = " ++ pathList paths ++ "\n") flattened ++ supporting
  let root := "(subLayers = [@weak.usda@])\nover \"Subject\" {\n" ++
    "    delete " ++ property ++ " = " ++ pathList edits.deleted ++ "\n" ++
    "    prepend " ++ property ++ " = " ++ pathList edits.prepended ++ "\n" ++
    "    append " ++ property ++ " = " ++ pathList edits.appended ++ "\n}\n"
  Json.mkObj [("id", toJson (family ++ "-target-edits")),
    ("weak", toJson (header ++ prim weakPaths false)), ("root", toJson (header ++ root)),
    ("composed", toJson (header ++ prim applied true))]

def files : List (String × String) :=
  let composition := fixtures.flatMap fun fixture =>
    [renderCase fixture .sublayer, renderCase fixture .reference, renderCase fixture .payload,
     renderVariant fixture false, renderVariant fixture true,
     renderClassArc fixture false, renderClassArc fixture true]
  let blocked := blockFixtures.flatMap fun fixture =>
    [renderCase fixture .sublayer, renderCase fixture .reference]
  let apiEdits := fixtures.flatMap fun fixture => [renderApiEdits fixture false, renderApiEdits fixture true]
  let targetEdits := [
    renderTargetEdits "geom" "Mesh" "rel proxyPrim" "Mesh" "",
    renderTargetEdits "skel" "Mesh" "rel skel:blendShapeTargets" "BlendShape" "SkelBindingAPI",
    renderTargetEdits "physics" "Mesh" "rel physics:simulationOwner" "PhysicsScene" "PhysicsCollisionAPI",
    renderTargetEdits "mtlx" "Material" "token outputs:mtlx:surface.connect" "Shader" "MaterialXConfigAPI",
    renderTargetEdits "vol" "Volume" "rel field:density" "OpenVDBAsset" ""]
  [("domain-roundtrip-vectors.json",
    (toJson (composition ++ blocked ++ apiEdits ++ targetEdits)).pretty ++ "\n")]

end Gen.DomainRoundtrip

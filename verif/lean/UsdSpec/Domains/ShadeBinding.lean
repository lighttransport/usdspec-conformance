import Mathlib.Tactic

/-!
# usdShade / usdLux binding and collection semantics

Exact models checked against OpenUSD 26.11 and LightUSD
(`lightusd::IsPathInCollection`, `lightusd::ComputeBoundMaterial`) by
`tests/next/test-domain-shade-runtime.py`.

Paths are lists of names (`[]` is the pseudo-root `/`).

* **Collections** (UsdCollectionMembershipQuery, relationship mode): the
  nearest ancestor-or-self entry among includes and excludes decides;
  `includeRoot` adds `[]` as an include; `explicitOnly` matches exact paths.
* **Bindings** (UsdShadeMaterialBindingAPI::ComputeBoundMaterial): the
  purpose passes are tried in order. Each pass walks leaf to root. A direct
  binding wins if nothing is bound yet or it is stronger. A matching
  collection binding wins if nothing is bound, if the current winner is on
  the same prim, or if it is stronger. The first pass with a target decides.
-/

namespace UsdSpec.Domains.ShadeBinding

abbrev SPath := List String

def isPrefix (a p : SPath) : Bool := a.isPrefixOf p

structure Collection where
  entries : List (SPath × Bool)  -- (path, include?)
  includeRoot : Bool := false
  explicitOnly : Bool := false
deriving Repr

/-- Entries with includeRoot folded in; later entries for the same path win. -/
def Collection.allEntries (c : Collection) : List (SPath × Bool) :=
  (if c.includeRoot then [([], true)] else []) ++ c.entries

/-- The nearest (longest) matching ancestor-or-self entry decides. -/
def Collection.includes (c : Collection) (p : SPath) : Bool :=
  if c.explicitOnly then
    (c.allEntries.filter (fun e => e.1 == p)).getLast?.any (·.2)
  else
    let found := c.allEntries.filter (fun e => isPrefix e.1 p)
    match found.foldl (fun best e =>
        match best with
        | none => some e
        | some b => if b.1.length ≤ e.1.length then some e else some b) none with
    | some e => e.2
    | none => false

/-- A nearer exclude beats a farther include, and a nearer include beats a
    farther exclude. -/
theorem nearest_entry_wins :
    let c : Collection := ⟨[(["A"], true), (["A", "B"], false), (["A", "B", "C"], true)], false, false⟩
    c.includes ["A", "B", "C", "E"] = true ∧ c.includes ["A", "B", "F"] = false ∧
      c.includes ["A", "G"] = true ∧ c.includes ["D"] = false := by decide

/-- includeRoot includes everything that is not excluded. -/
theorem includeRoot_all :
    let c : Collection := ⟨[(["A"], false)], true, false⟩
    c.includes ["D"] = true ∧ c.includes ["A", "B"] = false := by decide

/-- Bindings found on one prim for one purpose pass. -/
structure PrimBindings where
  path : SPath
  direct : Option (String × Bool)              -- (material, stronger?)
  collections : List (Collection × String × Bool)
deriving Repr

/-- One purpose pass over the leaf-to-root chain of a prim at `target`. -/
def pass (target : SPath) (chain : List PrimBindings) : Option String :=
  let step := fun (win : Option (String × SPath)) (pb : PrimBindings) =>
    let afterDirect := match pb.direct with
      | some (m, stronger) => if win.isNone || stronger then some (m, pb.path) else win
      | none => win
    match pb.collections.find? (fun (c, _, _) => c.includes target) with
    | some (_, m, stronger) =>
      let sameOwner := afterDirect.any (fun w => w.2 == pb.path)
      if afterDirect.isNone || sameOwner || stronger then some (m, pb.path) else afterDirect
    | none => afterDirect
  (chain.foldl step none).map (·.1)

/-- Passes in purpose order; the first with a target decides. -/
def boundMaterial (target : SPath) (passes : List (List PrimBindings)) : Option String :=
  passes.findSome? (pass target)

/-- A descendant's direct binding beats a weaker ancestor collection binding,
    but a stronger ancestor binding overrides it. -/
theorem weaker_vs_stronger :
    let coll : Collection := ⟨[(["W", "B"], true)], false, false⟩
    let leaf : PrimBindings := ⟨["W", "B", "Deep"], some ("Blue", false), []⟩
    pass ["W", "B", "Deep"] [leaf, ⟨["W"], none, [(coll, "Gold", false)]⟩] = some "Blue" ∧
    pass ["W", "B", "Deep"] [leaf, ⟨["W"], none, [(coll, "Gold", true)]⟩] = some "Gold" := by
  decide

/-- On one prim a matching collection binding beats the direct binding. -/
theorem collection_beats_direct_same_prim :
    let coll : Collection := ⟨[(["W", "A"], true)], false, false⟩
    pass ["W", "A"] [⟨["W", "A"], none, []⟩, ⟨["W"], some ("Red", false), [(coll, "Gold", false)]⟩]
      = some "Gold" := by decide

end UsdSpec.Domains.ShadeBinding

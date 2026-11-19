import Mathlib.Tactic

/-!
# usdPhysics object resolution

Exact models of the ownership rules of the OpenUSD 26.11 reference parser
(`UsdPhysicsLoadStageFromPrimRange`), checked against OpenUSD and LightUSD
(`lightusd::ResolvePhysics`) by `tests/next/test-domain-physics-runtime.py`.

A prim chain is listed leaf first: each entry records whether the prim has an
*enabled* rigid body and whether it has `PhysicsCollisionAPI`.
-/

namespace UsdSpec.Domains.PhysicsResolve

structure ChainPrim where
  path : String
  enabledBody : Bool
  collision : Bool
deriving Repr, DecidableEq

/-- Joint body: the first enabled rigid body walking up from the target,
    otherwise the highest collision prim, otherwise none. -/
def jointBody : List ChainPrim → Option String
  | [] => none
  | p :: rest =>
    if p.enabledBody then some p.path
    else match jointBody rest with
      | some b => some b
      | none => if p.collision then some p.path else none

/-- Collider ownership: the first enabled rigid body ancestor-or-self. -/
def colliderBody : List ChainPrim → Option String
  | [] => none
  | p :: rest => if p.enabledBody then some p.path else colliderBody rest

/-- A disabled body never owns: it is transparent to both walks. -/
theorem jointBody_skips_disabled (p : ChainPrim) (rest : List ChainPrim)
    (h : p.enabledBody = false) (hc : p.collision = false) :
    jointBody (p :: rest) = jointBody rest := by
  simp only [jointBody, h, hc]
  cases jointBody rest <;> rfl

/-- An enabled body above a collider wins over the collider itself. -/
theorem jointBody_prefers_body :
    jointBody [⟨"/S/C", false, true⟩, ⟨"/S", true, false⟩] = some "/S" := by decide

/-- Without bodies the *highest* collision ancestor is used. -/
theorem jointBody_highest_collision :
    jointBody [⟨"/S/C", false, true⟩, ⟨"/S", false, true⟩] = some "/S" := by decide

/-- Default gravity: magnitude 9.81 / metersPerUnit when unauthored (the
    fallback is -inf), direction -upAxis when unauthored (zero vector). -/
def gravityMagnitude (authored : Option Rat) (metersPerUnit : Rat) : Rat :=
  match authored with
  | some m => if 0 ≤ m then m else 981 / 100 / metersPerUnit
  | none => 981 / 100 / metersPerUnit

inductive UpAxis | x | y | z deriving DecidableEq, Repr

def defaultGravityDirection : UpAxis → List Rat
  | .x => [-1, 0, 0]
  | .y => [0, -1, 0]
  | .z => [0, 0, -1]

theorem centimeter_gravity : gravityMagnitude none (1/100) = 981 := by
  norm_num [gravityMagnitude]

/-- Merge groups: the first group of each merge name represents the set and
    collects every member's filtered groups; groups without a name stand alone. -/
structure Group where
  path : String
  mergeName : String
  filtered : List String
deriving Repr, DecidableEq

def mergeGroups (groups : List Group) : List (String × List String × List String) :=
  groups.foldl (fun acc g =>
    if g.mergeName = "" then acc ++ [(g.path, g.filtered, [])]
    else match acc.findIdx? (fun r =>
        (groups.find? (fun h => h.path = r.1)).any (fun h => h.mergeName = g.mergeName)) with
      | some i => acc.modify i (fun r => (r.1, r.2.1 ++ g.filtered, r.2.2 ++ [g.path]))
      | none => acc ++ [(g.path, g.filtered, [g.path])]) []

theorem merge_pair :
    mergeGroups [⟨"/A", "x", ["/B"]⟩, ⟨"/B", "x", ["/A"]⟩, ⟨"/C", "", ["/A"]⟩] =
      [("/A", ["/B", "/A"], ["/A", "/B"]), ("/C", ["/A"], [])] := by decide

end UsdSpec.Domains.PhysicsResolve

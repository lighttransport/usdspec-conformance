import Mathlib.Tactic

/-!
# usdMtlx interface and nodegraph input resolution

Model checked against OpenUSD usdMtlx and LightUSD by
`tests/next/test-domain-mtlx-runtime.py`. A node input is one of:

* a literal value,
* `interfacename`: the value of the enclosing nodegraph's interface input
  (which itself may be left to its authored default),
* a connection to another node's output inside the graph,
* `nodegraph`+`output`: the output of a top-level nodegraph.

Resolution never invents values: an interface input that the instantiating
shader does not override resolves to the interface default.
-/

namespace UsdSpec.Domains.MtlxResolve

inductive Src (α : Type)
  | literal (v : α)
  | interface (name : String)
  | node (id : Nat)
  deriving Repr

/-- Interface values of one nodegraph instance: authored defaults overridden by
    the instantiating shader. -/
def interfaceValue {α} (defaults overrides : String → Option α) (name : String) : Option α :=
  match overrides name with
  | some v => some v
  | none => defaults name

/-- Resolve a source to a literal, following node outputs through `outputOf`
    with fuel (a cycle or dead end resolves to `none`). -/
def resolve {α} (defaults overrides : String → Option α) (outputOf : Nat → Option (Src α)) :
    Nat → Src α → Option α
  | _, .literal v => some v
  | _, .interface n => interfaceValue defaults overrides n
  | 0, .node _ => none
  | fuel + 1, .node i =>
    match outputOf i with
    | some s => resolve defaults overrides outputOf fuel s
    | none => none

theorem resolve_literal {α} (d o : String → Option α) (f : Nat → Option (Src α)) (fuel : Nat) (v : α) :
    resolve d o f fuel (.literal v) = some v := by
  cases fuel <;> simp [resolve]

theorem override_wins {α} (d o : String → Option α) (name : String) (v : α)
    (h : o name = some v) : interfaceValue d o name = some v := by
  simp [interfaceValue, h]

theorem default_when_not_overridden {α} (d o : String → Option α) (name : String)
    (h : o name = none) : interfaceValue d o name = d name := by
  simp [interfaceValue, h]

/-- A node whose output is a self-loop never resolves. -/
theorem self_loop_none {α} (d o : String → Option α) (i fuel : Nat) :
    resolve d o (fun j => if j = i then some (.node i) else none) fuel (.node i) = none := by
  induction fuel with
  | zero => simp [resolve]
  | succ k ih => simpa [resolve] using ih

end UsdSpec.Domains.MtlxResolve

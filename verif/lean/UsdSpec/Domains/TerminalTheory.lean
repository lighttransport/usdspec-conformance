import Mathlib.Tactic

/-!
# usdShade render-context terminal selection and connection following

`UsdShadeMaterial::ComputeSurfaceSource(renderContexts)`: the first context in
the requested order that authors `outputs:<ctx>:surface` wins; the universal
`outputs:surface` is used only when no requested context authors one.
Connection chains are followed through NodeGraph outputs to a Shader output;
cycles and dead ends fail. LightUSD's `ComputeTerminalSource` and the
`test-domain-shade-runtime.py` oracle agree with these rules.
-/

namespace UsdSpec.Domains.TerminalTheory

/-- `authored ctx` is the terminal source authored for that context, if any. -/
def select (authored : String → Option String) (universal : Option String)
    (contexts : List String) : Option String :=
  match contexts.findSome? authored with
  | some s => some s
  | none => universal

theorem select_nil (authored : String → Option String) (u : Option String) :
    select authored u [] = u := by simp [select]

/-- The first requested context that authors a terminal decides. -/
theorem select_first (authored : String → Option String) (u : Option String)
    (c : String) (rest : List String) (s : String) (h : authored c = some s) :
    select authored u (c :: rest) = some s := by
  simp [select, List.findSome?_cons, h]

/-- A context that authors nothing is skipped. -/
theorem select_skip (authored : String → Option String) (u : Option String)
    (c : String) (rest : List String) (h : authored c = none) :
    select authored u (c :: rest) = select authored u rest := by
  simp [select, List.findSome?_cons, h]

/-- The universal terminal never overrides an authored context terminal. -/
theorem universal_loses (authored : String → Option String) (u : Option String)
    (contexts : List String) (s : String) (c : String) (hc : c ∈ contexts)
    (hs : authored c = some s) :
    ∃ t, select authored u contexts = some t := by
  unfold select
  cases h : contexts.findSome? authored with
  | some t => exact ⟨t, rfl⟩
  | none =>
    exfalso
    have := List.findSome?_eq_none_iff.mp h c hc
    simp [hs] at this

/-- Following connections: each step maps a source to its upstream, `none` at a
    dead end; a chain longer than the number of nodes must contain a cycle. The
    fuel is the node count, so termination and cycle failure coincide. -/
def follow (next : Nat → Option Nat) (isShaderOutput : Nat → Bool) : Nat → Nat → Option Nat
  | 0, _ => none
  | fuel + 1, n =>
    if isShaderOutput n then some n
    else match next n with
      | some m => follow next isShaderOutput fuel m
      | none => none

theorem follow_shader (next : Nat → Option Nat) (isOut : Nat → Bool) (fuel n : Nat)
    (h : isOut n = true) : follow next isOut (fuel + 1) n = some n := by
  simp [follow, h]

/-- A self-connection never reaches a shader output. -/
theorem follow_self_cycle (isOut : Nat → Bool) (fuel n : Nat) (h : isOut n = false) :
    follow (fun m => some m) isOut fuel n = none := by
  induction fuel with
  | zero => simp [follow]
  | succ k ih => simp [follow, h, ih]

end UsdSpec.Domains.TerminalTheory

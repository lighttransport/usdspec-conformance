import Mathlib.Tactic
import UsdSpec.Domains.ShadeBinding

/-!
# usdLux light linking

`UsdLuxLightAPI` links a light to geometry through the `lightLink` collection (default
`includeRoot = true`); shadow linking is the same rule on `shadowLink`.  A prim is illuminated
when it is a member of the collection (`ShadeBinding.Collection.includes`).  These theorems state
the order-independence facts a renderer relies on; the runtime oracle
(`test-domain-shade-runtime.py`, 70 memberships) checks the same rule against OpenUSD.
-/

namespace UsdSpec.Domains.LightLinking
open UsdSpec.Domains.ShadeBinding

/-- A light with the default `includeRoot` and no authored entries illuminates every prim. -/
theorem default_illuminates_all (p : SPath) :
    ({ entries := [], includeRoot := true, explicitOnly := false } : Collection).includes p = true := by
  simp only [Collection.includes, Collection.allEntries, isPrefix]
  rfl

/-- A light with an empty, non-root collection illuminates nothing. -/
theorem empty_illuminates_none (p : SPath) :
    ({ entries := [], includeRoot := false, explicitOnly := false } : Collection).includes p = false := by
  simp [Collection.includes, Collection.allEntries]

/-- The running best entry never exceeds a length bound that every candidate respects. -/
theorem foldl_best_le (K : Nat) :
    ∀ (l : List (SPath × Bool)) (best : Option (SPath × Bool)),
      (∀ b, best = some b → b.1.length ≤ K) → (∀ e ∈ l, e.1.length ≤ K) →
      ∀ b, (l.foldl (fun best e => match best with
          | none => some e
          | some b => if b.1.length ≤ e.1.length then some e else some b) best) = some b →
        b.1.length ≤ K := by
  intro l
  induction l with
  | nil => intro best hb _ b h; exact hb b h
  | cons e rest ih =>
    intro best hb he b h
    simp only [List.foldl_cons] at h
    refine ih _ ?_ (fun x hx => he x (List.mem_cons_of_mem _ hx)) b h
    intro b' hb'
    cases best with
    | none => simp at hb'; subst hb'; exact he e (List.mem_cons_self ..)
    | some bb =>
      simp only at hb'
      split_ifs at hb' with hle
      · have := Option.some.inj hb'; subst this; exact he e (List.mem_cons_self ..)
      · have := Option.some.inj hb'; subst this; exact hb _ rfl

/-- Appending an entry that is at least as near to `p` as every earlier ancestor entry decides `p`
(the nearest ancestor-or-self entry wins; among equally near entries the later one wins). -/
theorem nearest_entry_decides (c : Collection) (q : SPath) (b : Bool) (p : SPath)
    (hq : isPrefix q p = true)
    (hnear : ∀ e ∈ c.allEntries, isPrefix e.1 p = true → e.1.length ≤ q.length) :
    (⟨c.entries ++ [(q, b)], c.includeRoot, false⟩ : Collection).includes p = b := by
  have hall : Collection.allEntries ⟨c.entries ++ [(q, b)], c.includeRoot, false⟩ =
      c.allEntries ++ [(q, b)] := by
    simp [Collection.allEntries, List.append_assoc]
  have hnear' : ∀ e ∈ c.allEntries.filter (fun e => isPrefix e.1 p), e.1.length ≤ q.length := by
    intro e he
    rw [List.mem_filter] at he
    exact hnear e he.1 he.2
  unfold Collection.includes
  simp only [hall, Bool.false_eq_true, ite_false, List.filter_append, List.filter_cons, hq,
    List.filter_nil, ite_true, List.foldl_append, List.foldl_cons, List.foldl_nil]
  cases hf : List.foldl (fun best e => match best with
      | none => some e
      | some b => if b.1.length ≤ e.1.length then some e else some b) none
      (c.allEntries.filter (fun e => isPrefix e.1 p)) with
  | none => simp
  | some bb =>
    have := foldl_best_le q.length _ none (by intro b h; cases h) hnear' bb hf
    simp [this]

end UsdSpec.Domains.LightLinking

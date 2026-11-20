import Mathlib.Tactic

/-!
# usdGeom transform stacks and PointInstancer masks

General statements behind `test-domain-geom-runtime.py`, over exact rationals.

* Affine maps `x ↦ a x + b` model a transform stack along one axis. Composition
  is associative with an identity, so the evaluation order of `xformOpOrder`
  is the only thing that matters, and `!invert!` ops cancel their partner.
* `resetXformStack` makes the world transform independent of the parent.
* A PointInstancer instance is drawn exactly when it is neither inactive nor
  invisible. The result does not depend on the order or duplication of ids.
-/

namespace UsdSpec.Domains.GeomTheory

structure Aff where
  a : Rat
  b : Rat
deriving DecidableEq, Repr

def Aff.apply (f : Aff) (x : Rat) : Rat := f.a * x + f.b

/-- `f.comp g` applies `g` first, then `f` (column-vector convention). -/
def Aff.comp (f g : Aff) : Aff := ⟨f.a * g.a, f.a * g.b + f.b⟩

def Aff.id : Aff := ⟨1, 0⟩

theorem comp_apply (f g : Aff) (x : Rat) : (f.comp g).apply x = f.apply (g.apply x) := by
  simp [Aff.comp, Aff.apply]; ring

theorem comp_assoc (f g h : Aff) : (f.comp g).comp h = f.comp (g.comp h) := by
  simp [Aff.comp]; constructor <;> ring

theorem comp_id (f : Aff) : f.comp Aff.id = f := by simp [Aff.comp, Aff.id]
theorem id_comp (f : Aff) : Aff.id.comp f = f := by simp [Aff.comp, Aff.id]

/-- The inverse of an op with a nonzero scale, as `!invert!` produces. -/
def Aff.inv (f : Aff) : Aff := ⟨1 / f.a, -f.b / f.a⟩

theorem inv_comp (f : Aff) (h : f.a ≠ 0) : f.inv.comp f = Aff.id := by
  simp only [Aff.inv, Aff.comp, Aff.id]
  congr 1 <;> field_simp <;> ring

/-- Local transform of a prim: ops folded in `xformOpOrder` order. The first
    op in the list is the outermost, so it is applied last. -/
def stack (ops : List Aff) : Aff := ops.foldr Aff.comp Aff.id

theorem stack_append (xs ys : List Aff) : stack (xs ++ ys) = (stack xs).comp (stack ys) := by
  induction xs with
  | nil => simp [stack, id_comp]
  | cons x rest ih =>
    simp only [stack, List.foldr_append] at ih ⊢
    simp only [List.cons_append, List.foldr_cons]
    rw [ih, comp_assoc]

/-- World transform: `resetXformStack` discards the parent's contribution. -/
def world (parent : Aff) (reset : Bool) (ops : List Aff) : Aff :=
  if reset then stack ops else parent.comp (stack ops)

theorem reset_ignores_parent (p q : Aff) (ops : List Aff) :
    world p true ops = world q true ops := by simp [world]

theorem no_reset_composes (p : Aff) (ops : List Aff) :
    world p false ops = p.comp (stack ops) := by simp [world]

/-- An op followed by its inverse is the identity, wherever it sits in the stack. -/
theorem stack_cancel (pre post : List Aff) (f : Aff) (h : f.a ≠ 0) :
    stack (pre ++ [f.inv, f] ++ post) = stack (pre ++ post) := by
  simp only [stack_append]
  have : stack [f.inv, f] = Aff.id := by
    simp [stack, comp_id, inv_comp f h]
  rw [this, comp_id]

/-- A PointInstancer instance is drawn unless it is inactive or invisible. -/
def drawn (inactive invisible : List Nat) (id : Nat) : Bool :=
  !(inactive.contains id) && !(invisible.contains id)

theorem drawn_comm (i v : List Nat) (id : Nat) :
    drawn i v id = (!(v.contains id) && !(i.contains id)) := by
  simp [drawn, Bool.and_comm]

theorem drawn_dup (i v : List Nat) (id : Nat) :
    drawn (i ++ i) v id = drawn i v id := by
  simp [drawn]

theorem drawn_mono (i v w : List Nat) (id : Nat) (h : drawn i (v ++ w) id = true) :
    drawn i v id = true := by
  simp [drawn, List.contains_append] at h ⊢
  tauto

end UsdSpec.Domains.GeomTheory

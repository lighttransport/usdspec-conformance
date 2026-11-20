import UsdSpec.Composition.NamespaceMap
import UsdSpec.Composition.Instancing

/-!
# Instance namespace mapping connection (AOUSD Core 1.1.0)

Bridges `UsdSpec.Composition.Instancing` (which instance prims may share a
prototype: L5537-5543) and `UsdSpec.Composition.NamespaceMap` (how a prototype
subtree's paths are mapped into each instance: L5375-5400, L4413-4448).

The runtime implements this by carrying the composed mapping on an instance
proxy and inheriting it until a nested instance introduces a new mapping. The
theorems here are the algebraic contract for that propagation.
-/
namespace UsdSpec.InstanceNamespaceMap

open UsdSpec.NamespaceMap

/-- A nested instance's mapping composed with its outer instance's mapping is
the single most-specific pair from the nested prototype to the outer instance.
`compose f g` applies `g` first, then `f` (L5385-5387). -/
theorem nested_outer_compose (proto mid inst : PrimPath) :
    compose [(mid, inst)] [(proto, mid)] = [(proto, inst)] := by
  simp [compose, mapPath, best]

/-- The composed mapping reaches descendants at any depth. This is the
contract for inheriting the effective mapping on an instance proxy. -/
theorem nested_descendant (proto inst : PrimPath) (suffix : PrimPath) :
    mapPath [(proto, inst)] (proto ++ suffix) = some (inst ++ suffix) :=
  mapPath_single_append proto inst suffix

/-- Using only the outer mapping cannot map a path that lives in the nested
prototype's namespace, unless the prototype happens to be under the outer
instance. That is the failure mode for nested instances shared by two
different outer prototypes. -/
theorem outer_only_misses_nested (outerProto outerInst path : PrimPath)
    (h : ¬outerProto <+: path) :
    mapPath [(outerProto, outerInst)] path = none := by
  apply mapPath_of_best_none
  apply best_eq_none
  intro a ha hap
  simp at ha
  rcases ha with rfl
  exact h hap

/-- Holder-mode flattening represents the nested prototype as an internal
reference, but produces the same namespace mapping as native instancing. -/
theorem holder_native_equivalent (holder inst proto : PrimPath)
    (suffix : PrimPath) :
    mapPath [(holder, inst)] (holder ++ suffix) =
      mapPath [(proto, inst)] (proto ++ suffix) := by
  rw [mapPath_single_append, mapPath_single_append]

/-- The mapping target is injective for distinct instance roots with
prefix-free targets, so two meshes cannot be assigned the same path. -/
theorem distinct_instances_distinct_paths (proto inst₁ inst₂ : PrimPath)
    (h : inst₁ ≠ inst₂) (suffix : PrimPath) :
    mapPath [(proto, inst₁)] (proto ++ suffix) ≠
      mapPath [(proto, inst₂)] (proto ++ suffix) := by
  simp [mapPath_single_append, h]

end UsdSpec.InstanceNamespaceMap

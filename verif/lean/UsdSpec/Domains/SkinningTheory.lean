import Mathlib.Tactic
import UsdSpec.Domains.SkeletonValidation

/-!
# usdSkel skinning and blend-shape theory

General statements behind the runtime oracles (`skin_compare`,
`test-domain-skeleton-deformation.py`), proved over exact rationals.

* Linear blend skinning is an affine combination: when the influence weights
  sum to one, joints that agree on a translation move the point by exactly that
  translation, and a single full-weight influence is the joint transform.
* Blend-shape in-between shapes interpolate piecewise linearly; the result is
  continuous at the knots and hits the authored offsets there.
* The dual-quaternion half-turn probe returns a unit vector, so the
  normalized blend never changes the length of a rotated unit vector.
-/

namespace UsdSpec.Domains.SkinningTheory

open UsdSpec.Domains.SkeletonValidation

def weightSum (influences : List (Rat × Rat)) : Rat := (influences.map (·.1)).sum

/-- Translation-only linear blend skinning splits into the point scaled by the
    weight sum plus the weighted translation. -/
theorem blend_split (point : Rat) (influences : List (Rat × Rat)) :
    blendTranslatedCoordinate point influences =
      point * weightSum influences + (influences.map fun i => i.1 * i.2).sum := by
  induction influences with
  | nil => simp [blendTranslatedCoordinate, weightSum]
  | cons i rest ih =>
    simp only [blendTranslatedCoordinate, weightSum, List.map_cons, List.sum_cons] at ih ⊢
    rw [ih]; ring

/-- Weights summing to one: the blend is `point` plus the weighted translation. -/
theorem blend_partition_of_unity (point : Rat) (influences : List (Rat × Rat))
    (h : weightSum influences = 1) :
    blendTranslatedCoordinate point influences =
      point + (influences.map fun i => i.1 * i.2).sum := by
  rw [blend_split, h]; ring

/-- Two influences with weights `w` and `1 - w` and the same translation give
    exactly that translation, so joints that move together never shear. -/
theorem blend_common_translation (point t w : Rat) :
    blendTranslatedCoordinate point [(w, t), (1 - w, t)] = point + t := by
  simp [blendTranslatedCoordinate]; ring

/-- One blend-shape in-between segment: linear interpolation of the authored
    offsets `oa` at weight `a` and `ob` at weight `b`. -/
def segment (a b oa ob w : Rat) : Rat := oa + (w - a) / (b - a) * (ob - oa)

theorem segment_left (a b oa ob : Rat) : segment a b oa ob a = oa := by
  simp [segment]

theorem segment_right (a b oa ob : Rat) (h : a ≠ b) : segment a b oa ob b = ob := by
  have : b - a ≠ 0 := sub_ne_zero.mpr (Ne.symm h)
  simp only [segment]; field_simp; ring

/-- Adjacent segments agree at the shared knot, so the piecewise-linear
    in-between curve is continuous. -/
theorem segments_continuous (a b c oa ob oc : Rat) (h : a ≠ b) :
    segment a b oa ob b = segment b c ob oc b := by
  rw [segment_right a b oa ob h]; simp [segment]

/-- Unit X vector after the aligned dual-quaternion blend of identity and a
    Z rotation, as in `dualQuaternionUnitX`: always a unit vector. -/
theorem dualQuaternion_unit (w z : Rat) (h : w * w + z * z ≠ 0) :
    (dualQuaternionUnitX w z).1 ^ 2 + (dualQuaternionUnitX w z).2 ^ 2 = 1 := by
  simp only [dualQuaternionUnitX]
  have h2 : (w * w + z * z) ^ 2 ≠ 0 := pow_ne_zero 2 h
  rw [div_pow, div_pow, ← add_div, div_eq_one_iff_eq h2]
  ring

end UsdSpec.Domains.SkinningTheory

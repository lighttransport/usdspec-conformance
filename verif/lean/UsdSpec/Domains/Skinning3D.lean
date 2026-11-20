import Mathlib.Tactic

/-!
# usdSkel linear blend skinning in three dimensions

`UsdSkelSkinPointsLBS`: a point is moved by `Σᵢ wᵢ (Mᵢ p + tᵢ)` where `Mᵢ`, `tᵢ` are the linear part and
translation of joint `i`'s skinning transform (rotation, scale, shear) and `wᵢ` the normalized influence
weights.  `SkinningTheory` covers translation-only joints; these statements are the general 3D form, over any
index type and exact rationals.
-/

namespace UsdSpec.Domains.Skinning3D

open Matrix

variable {ι : Type*} [Fintype ι]

/-- Linear blend skinning of one point. -/
def lbs (w : ι → ℚ) (M : ι → Matrix (Fin 3) (Fin 3) ℚ) (t : ι → Fin 3 → ℚ) (p : Fin 3 → ℚ) :
    Fin 3 → ℚ :=
  ∑ i, w i • ((M i).mulVec p + t i)

/-- Blending is affine in the point: it applies the blended matrix and the blended translation. -/
theorem lbs_affine (w : ι → ℚ) (M : ι → Matrix (Fin 3) (Fin 3) ℚ) (t : ι → Fin 3 → ℚ)
    (p : Fin 3 → ℚ) :
    lbs w M t p = (∑ i, w i • M i).mulVec p + ∑ i, w i • t i := by
  unfold lbs
  simp only [smul_add, Finset.sum_add_distrib]
  congr 1
  rw [Matrix.sum_mulVec]
  refine Finset.sum_congr rfl fun i _ => ?_
  rw [Matrix.smul_mulVec]

/-- Weights summing to one and one common joint transform: the point moves by exactly that transform. -/
theorem lbs_common (w : ι → ℚ) (hw : ∑ i, w i = 1) (M : Matrix (Fin 3) (Fin 3) ℚ) (t : Fin 3 → ℚ)
    (p : Fin 3 → ℚ) :
    lbs w (fun _ => M) (fun _ => t) p = M.mulVec p + t := by
  rw [lbs_affine, ← Finset.sum_smul, ← Finset.sum_smul, hw, one_smul, one_smul]

/-- Identity joints leave every point fixed (the bind pose reproduces the rest shape). -/
theorem lbs_identity (w : ι → ℚ) (hw : ∑ i, w i = 1) (p : Fin 3 → ℚ) :
    lbs w (fun _ => 1) (fun _ => 0) p = p := by
  rw [lbs_common w hw]; simp

/-- Linearity in the weights: splitting the influences into two groups adds the two blends. -/
theorem lbs_add_weights (w₁ w₂ : ι → ℚ) (M : ι → Matrix (Fin 3) (Fin 3) ℚ) (t : ι → Fin 3 → ℚ)
    (p : Fin 3 → ℚ) :
    lbs (fun i => w₁ i + w₂ i) M t p = lbs w₁ M t p + lbs w₂ M t p := by
  unfold lbs
  rw [← Finset.sum_add_distrib]
  refine Finset.sum_congr rfl fun i _ => ?_
  rw [add_smul]

end UsdSpec.Domains.Skinning3D

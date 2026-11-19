import Mathlib.Tactic

/-!
# usdGeom runtime evaluation

Exact (rational) models of the usdGeom runtime computations compared by
`tests/next/test-domain-geom-runtime.py` against OpenUSD 26.11 and LightUSD:

* `instanceMatrix`: the PointInstancer per-instance transform, scale then
  orient then translate, in Gf memory layout (row-major, row vectors,
  translation in the last row), for a unit quaternion `(w, x, y, z)`;
* `motionPosition`: velocity/acceleration extrapolation from the lower
  bracketing positions sample (`dt` in seconds);
* `shapeExtent` / `pointsExtent` / `curvesExtent`: Boundable extents.

`pointsExtent` models OpenUSD's `UsdGeomPoints` rule, which requires one width
per point. `pointsExtentByInterpolation` is the schema-documented reading,
where widths are sized by their interpolation. `points_constant_width_gap`
shows that the two differ (issues/OpenUSD/13).
-/

namespace UsdSpec.Domains.GeomRuntime

/-- Row-major 4x4 matrix as 16 lanes. -/
abbrev Mat := List Rat

/-- Gf-layout instance matrix `S * R * T` (row vectors) for unit `q`. -/
def instanceMatrix (t : Rat × Rat × Rat) (q : Rat × Rat × Rat × Rat)
    (s : Rat × Rat × Rat) : Mat :=
  let (tx, ty, tz) := t
  let (w, x, y, z) := q
  let (sx, sy, sz) := s
  -- Row r is s_r times the image of basis vector e_r under the rotation.
  [ sx * (1 - 2*(y*y + z*z)), sx * (2*(x*y + w*z)), sx * (2*(x*z - w*y)), 0,
    sy * (2*(x*y - w*z)), sy * (1 - 2*(x*x + z*z)), sy * (2*(y*z + w*x)), 0,
    sz * (2*(x*z + w*y)), sz * (2*(y*z - w*x)), sz * (1 - 2*(x*x + y*y)), 0,
    tx, ty, tz, 1 ]

/-- The translation occupies lanes 12..14 (last row). -/
theorem instanceMatrix_translation (t : Rat × Rat × Rat) (q) (s) :
    ((instanceMatrix t q s).drop 12).take 3 = [t.1, t.2.1, t.2.2] := by
  obtain ⟨tx, ty, tz⟩ := t; obtain ⟨w, x, y, z⟩ := q; obtain ⟨sx, sy, sz⟩ := s
  simp [instanceMatrix]

/-- Identity orientation with unit scale is a pure translation. -/
theorem instanceMatrix_identity (t : Rat × Rat × Rat) :
    instanceMatrix t (1, 0, 0, 0) (1, 1, 1) =
      [1,0,0,0, 0,1,0,0, 0,0,1,0, t.1, t.2.1, t.2.2, 1] := by
  obtain ⟨tx, ty, tz⟩ := t; simp [instanceMatrix]

/-- The unit quaternion `(3/5, 0, 0, 4/5)` turns +X toward +Y, so row 0 is
    `(-7/25, 24/25, 0)` with row vectors. LightUSD previously stored the
    transpose, which has `-24/25` in lane 1. -/
theorem instanceMatrix_rational_z :
    (instanceMatrix (0, 0, 0) (3/5, 0, 0, 4/5) (1, 1, 1)).take 3 = [-7/25, 24/25, 0] := by
  norm_num [instanceMatrix]

/-- Velocity/acceleration motion from the lower bracketing sample. -/
def motionPosition (p v a dt : Rat) : Rat := p + v * dt + a * dt * dt / 2

theorem motionPosition_no_accel (p v dt : Rat) : motionPosition p v 0 dt = p + v * dt := by
  simp [motionPosition]

/-- Axis index 0/1/2 for X/Y/Z. -/
inductive Axis | x | y | z deriving DecidableEq, Repr

/-- Symmetric box `[-h, h]` with the `axis` lane `along` and the others `across`. -/
def axisBox (axis : Axis) (along across : Rat) : List Rat :=
  let h := match axis with
    | .x => [along, across, across]
    | .y => [across, along, across]
    | .z => [across, across, along]
  h.map (fun v => -v) ++ h

/-- Closed-form Boundable extents (min.xyz ++ max.xyz) with schema fallbacks
    supplied by the caller. Capsule_1 needs a square root and is omitted. -/
inductive Shape
  | cube (size : Rat)
  | sphere (radius : Rat)
  | cylinder (height radius : Rat) (axis : Axis)
  | cone (height radius : Rat) (axis : Axis)
  | capsule (height radius : Rat) (axis : Axis)
  | cylinder1 (height radiusTop radiusBottom : Rat) (axis : Axis)
  | plane (width length : Rat) (axis : Axis)

def shapeExtent : Shape → List Rat
  | .cube size => axisBox .z (size / 2) (size / 2)
  | .sphere r => axisBox .z r r
  | .cylinder h r axis => axisBox axis (h / 2) r
  | .cone h r axis => axisBox axis (h / 2) r
  | .capsule h r axis => axisBox axis (h / 2 + r) r
  | .cylinder1 h rt rb axis => axisBox axis (h / 2) (max rt rb)
  | .plane w l axis =>
    let hw := w / 2; let hl := l / 2
    let m := match axis with
      | .x => [0, hl, hw]
      | .y => [hw, 0, hl]
      | .z => [hw, hl, 0]
    m.map (fun v => -v) ++ m

theorem cube_fallback_extent : shapeExtent (.cube 2) = [-1, -1, -1, 1, 1, 1] := by
  norm_num [shapeExtent, axisBox]

/-- The capsule cap adds the radius along the axis. -/
theorem capsule_cap (h r : Rat) :
    (shapeExtent (.capsule h r .y))[4]? = some (h / 2 + r) := by
  simp [shapeExtent, axisBox]

private def boundsOf (pts : List (Rat × Rat × Rat)) (grow : Nat → Rat) : Option (List Rat) :=
  match pts with
  | [] => none
  | p :: _ =>
    let init := ([p.1 - grow 0, p.2.1 - grow 0, p.2.2 - grow 0],
                 [p.1 + grow 0, p.2.1 + grow 0, p.2.2 + grow 0])
    let (lo, hi) := (pts.zipIdx.foldl (fun (acc : List Rat × List Rat) (q, i) =>
      let g := grow i
      (List.zipWith min acc.1 [q.1 - g, q.2.1 - g, q.2.2 - g],
       List.zipWith max acc.2 [q.1 + g, q.2.1 + g, q.2.2 + g])) init)
    some (lo ++ hi)

/-- OpenUSD `UsdGeomPoints` extent: widths must have one entry per point. -/
def pointsExtent (pts : List (Rat × Rat × Rat)) (widths : Option (List Rat)) :
    Option (List Rat) :=
  match widths with
  | none => boundsOf pts (fun _ => 0)
  | some ws => if ws.length = pts.length then boundsOf pts (fun i => ws.getD i 0 / 2) else none

/-- Schema-documented reading: a single constant width applies to every point. -/
def pointsExtentByInterpolation (pts : List (Rat × Rat × Rat)) (widths : Option (List Rat))
    (constant : Bool) : Option (List Rat) :=
  match widths, constant with
  | some [w], true => boundsOf pts (fun _ => w / 2)
  | _, _ => pointsExtent pts widths

/-- Curves: control-point bounds grown by the maximum width / 2. -/
def curvesExtent (pts : List (Rat × Rat × Rat)) (widths : List Rat) : Option (List Rat) :=
  boundsOf pts (fun _ => (widths.foldl max 0) / 2)

/-- issues/OpenUSD/13: a legal constant width yields no OpenUSD extent. -/
theorem points_constant_width_gap :
    pointsExtent [(0,0,0), (2,0,0)] (some [1]) = none ∧
    pointsExtentByInterpolation [(0,0,0), (2,0,0)] (some [1]) true =
      some [-1/2, -1/2, -1/2, 5/2, 1/2, 1/2] := by
  constructor
  · simp [pointsExtent]
  · simp [pointsExtentByInterpolation, boundsOf, List.zipIdx]
    norm_num

end UsdSpec.Domains.GeomRuntime

/-
  Proofs for T1 crate pack helper.
-/
import UsdSpecC.Gen
import UsdSpecC.Logic
import UsdSpecC.Hoare

namespace UsdSpecC.Proofs

open UsdSpecC

set_option linter.unusedSimpArgs false

/-- **`lspec_crate_pack_byte`** body returns `(a&3)|(b&3)<<2|(c&3)<<4|(d&3)<<6` as `u8`. -/
theorem pack_byte_exs (loc : Locals) (m : Mem)
    (a b c d : Nat)
    (h0 : loc 0 = some (.int IntTy.u32 a))
    (h1 : loc 1 = some (.int IntTy.u32 b))
    (h2 : loc 2 = some (.int IntTy.u32 c))
    (h3 : loc 3 = some (.int IntTy.u32 d)) :
    ExS Gen.prog ⟨loc, m, false⟩ Gen.lspec_crate_pack_byte.body
      (.ret (some (.int IntTy.u8
        ((((a &&& 3) ||| ((b &&& 3) * 4) ||| ((c &&& 3) * 16) ||| ((d &&& 3) * 64)) % 256)))))
      ⟨loc.upd 4 (.int IntTy.u32
        ((a &&& 3) ||| ((b &&& 3) * 4) ||| ((c &&& 3) * 16) ||| ((d &&& 3) * 64))), m, false⟩ := by
  have hb4 : (b &&& 3) * 4 < 4294967296 := by
    have : b &&& 3 < 4 := by
      have h := Nat.and_lt_two_pow b (by decide : 3 < 2^2)
      simpa using h
    omega
  have hc16 : (c &&& 3) * 16 < 4294967296 := by
    have : c &&& 3 < 4 := by
      have h := Nat.and_lt_two_pow c (by decide : 3 < 2^2)
      simpa using h
    omega
  have hd64 : (d &&& 3) * 64 < 4294967296 := by
    have : d &&& 3 < 4 := by
      have h := Nat.and_lt_two_pow d (by decide : 3 < 2^2)
      simpa using h
    omega
  refine ExS.of_eq 20 (fun n => ?_)
  simp [Gen.lspec_crate_pack_byte, execStmt, evalExpr, evalBin, evalBinInt, binInt,
    evalCast, evalUn, intOf, IntTy.u32, IntTy.u8, IntTy.i32, IntTy.toInt,
    IntTy.modulus, IntTy.wrap, isPtr, guard, truthy, Res.bind_eq, Res.bind_ok,
    h0, h1, h2, h3, Locals.upd,
    Nat.mod_eq_of_lt hb4, Nat.mod_eq_of_lt hc16, Nat.mod_eq_of_lt hd64, *]

/-- **`lspec_crate_pack_byte`** via `callFunc`. -/
theorem pack_byte_call (a b c d : Nat)
    (ha : a < 4294967296) (hb : b < 4294967296)
    (hc : c < 4294967296) (hd : d < 4294967296)
    (m : Mem) :
    ∃ K, ∀ n, K ≤ n →
      callFunc Gen.prog n Gen.fid_lspec_crate_pack_byte
        [.int IntTy.u32 a, .int IntTy.u32 b, .int IntTy.u32 c, .int IntTy.u32 d] m
      = .ok (some (.int IntTy.u8
          ((((a &&& 3) ||| ((b &&& 3) * 4) ||| ((c &&& 3) * 16) ||| ((d &&& 3) * 64)) % 256))),
        m) := by
  -- Frame locals at the call site.
  have h0 : frameLocals [0, 1, 2, 3]
      [.int IntTy.u32 a, .int IntTy.u32 b, .int IntTy.u32 c, .int IntTy.u32 d] 0
      = some (.int IntTy.u32 a) := rfl
  have h1 : frameLocals [0, 1, 2, 3]
      [.int IntTy.u32 a, .int IntTy.u32 b, .int IntTy.u32 c, .int IntTy.u32 d] 1
      = some (.int IntTy.u32 b) := rfl
  have h2 : frameLocals [0, 1, 2, 3]
      [.int IntTy.u32 a, .int IntTy.u32 b, .int IntTy.u32 c, .int IntTy.u32 d] 2
      = some (.int IntTy.u32 c) := rfl
  have h3 : frameLocals [0, 1, 2, 3]
      [.int IntTy.u32 a, .int IntTy.u32 b, .int IntTy.u32 c, .int IntTy.u32 d] 3
      = some (.int IntTy.u32 d) := rfl
  have hex : ExS Gen.prog
      ⟨frameLocals [0, 1, 2, 3]
        [.int IntTy.u32 a, .int IntTy.u32 b, .int IntTy.u32 c, .int IntTy.u32 d], m, false⟩
      Gen.lspec_crate_pack_byte.body
      (.ret (some (.int IntTy.u8
        ((((a &&& 3) ||| ((b &&& 3) * 4) ||| ((c &&& 3) * 16) ||| ((d &&& 3) * 64)) % 256)))))
      ⟨(frameLocals [0, 1, 2, 3]
        [.int IntTy.u32 a, .int IntTy.u32 b, .int IntTy.u32 c, .int IntTy.u32 d]).upd 4
        (.int IntTy.u32 ((a &&& 3) ||| ((b &&& 3) * 4) ||| ((c &&& 3) * 16) ||| ((d &&& 3) * 64))), m, false⟩ :=
    pack_byte_exs _ m a b c d h0 h1 h2 h3
  have hf : Gen.prog Gen.fid_lspec_crate_pack_byte = some Gen.lspec_crate_pack_byte := by
    simp [Gen.prog, Gen.fid_lspec_crate_pack_byte]
  have hlen : Gen.lspec_crate_pack_byte.params.length
      = (([.int IntTy.u32 a, .int IntTy.u32 b, .int IntTy.u32 c, .int IntTy.u32 d] : List Val).length) := by
    simp [Gen.lspec_crate_pack_byte]
  exact callFunc_of_ExS hf hlen hex

end UsdSpecC.Proofs

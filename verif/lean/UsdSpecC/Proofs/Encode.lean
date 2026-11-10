/-
  Crate delta-codec proofs via `Splice`, mirroring tinygltf
  `Proofs/Wr32.lean` (`store_int`, `splice`).
  Landed: `lspec_crate_encode_delta32` common branch (no store) via
  `seq_ret`, the generalized 1-byte tail fragment (`set` cast chain +
  single `store` + `ret 1`, postcondition `splice` of the low byte),
  whole-function `encode_delta32_call` for the code-1 branch (guards
  `-128 ≤ d ≤ 127`), the 2-byte tail fragment, and whole-function
  `encode_delta32_call2` for the code-2 branch (guards
  `-32768 ≤ d ≤ 32767`). The 4-byte tail and the `decode_delta32` codes
  remain TODO.
-/
import UsdSpecC.Gen
import UsdSpecC.Logic
import UsdSpecC.Hoare
import UsdSpecC.Splice

namespace UsdSpecC.Proofs

open UsdSpecC

set_option linter.unusedSimpArgs false
set_option linter.unusedVariables false
set_option maxRecDepth 4000
set_option linter.deprecated false

theorem truthy_boolVal (b : Bool) : truthy (boolVal b) = .ok b := by
  cases b <;> rfl

/-- The low byte of `n` is just its remainder modulo 256. -/
theorem and255_mod (n : Nat) : n &&& 255 = n % 256 := by
  simpa using Nat.and_two_pow_sub_one_eq_mod n 8

/-- Evaluation of a 32-bit arithmetic right shift by 8. -/
theorem evalShr8 (x : Nat) (h : x < 65536) :
    evalBin .shr (some IntTy.i32) (.int IntTy.i32 x) (.int IntTy.i32 8)
      = .ok (.int IntTy.i32 (x / 256)) := by
  simp [evalBin, evalBinInt, binInt, isPtr, intOf, IntTy.i32, IntTy.toInt,
    IntTy.modulus, IntTy.wrap, Res.pure_eq, Res.bind_eq, Res.bind_ok,
    UsdSpecC.guard] <;> omega

/-- `IntTy.toInt i32` is injective on representations `< 2^32`: two
    two's-complement representations with the same value are equal. -/
theorem toInt_i32_inj {a b : Nat} (ha : a < 4294967296) (hb : b < 4294967296)
    (h : IntTy.toInt IntTy.i32 a = IntTy.toInt IntTy.i32 b) : a = b := by
  simp only [IntTy.toInt, IntTy.i32, IntTy.width, IntTy.signed, IntTy.modulus] at h
  by_cases ha2 : 2147483648 ≤ a <;> by_cases hb2 : 2147483648 ≤ b <;>
    simp [ha2, hb2] at h <;> omega

/-- `d == common` condition for delta encoding (signed comparison). -/
theorem enc_eq_eval (common d : Nat) (s : State)
    (h0 : s.locals 0 = some (.int IntTy.i32 common))
    (h1 : s.locals 1 = some (.int IntTy.i32 d)) :
    EvE Gen.prog s
      (.bin .eq (some IntTy.i32) (.var 1) (.var 0))
      (boolVal (decide (IntTy.toInt IntTy.i32 d = IntTy.toInt IntTy.i32 common))) := by
  refine EvE.of_eq 5 (fun f => ?_)
  simp [evalExpr, evalBin, evalBinInt, binInt, intOf, IntTy.i32, IntTy.toInt,
    IntTy.modulus, isPtr, guard, Res.bind_eq, Res.bind_ok, h0, h1]

/-- Common branch writes nothing and returns 0. -/
theorem encode_delta32_common (common d : Nat) (s : State)
    (h0 : s.locals 0 = some (.int IntTy.i32 common))
    (h1 : s.locals 1 = some (.int IntTy.i32 d))
    (hc : common < 4294967296) (hd : d < 4294967296)
    (heq : d = common) :
    ExS Gen.prog s
      (.ite (.bin .eq (some IntTy.i32) (.var 1) (.var 0))
        (.ret (some (.cast IntTy.u32 (.const (.int IntTy.i32 0)))))
        (.skip))
      (.ret (some (.int IntTy.u32 0))) s := by
  have hcv := enc_eq_eval common d s h0 h1
  have hct := truthy_boolVal (decide (IntTy.toInt IntTy.i32 d = IntTy.toInt IntTy.i32 common))
  have htrue : decide (IntTy.toInt IntTy.i32 d = IntTy.toInt IntTy.i32 common) = true := by
    rw [decide_eq_true_eq]
    rw [heq]
  rw [htrue] at hcv hct
  have hone : EvE Gen.prog s (.cast IntTy.u32 (.const (.int IntTy.i32 0)))
      (.int IntTy.u32 0) := by
    refine EvE.of_eq 5 (fun f => ?_)
    simp [evalExpr, evalCast, intOf, IntTy.u32, IntTy.i32, IntTy.toInt, IntTy.modulus,
      IntTy.wrap, isPtr]
  refine ExS.ite hcv hct ?_
  exact ExS.ret hone

/-- Whole delta body on the common branch (no store; `seq_ret` drops the rest). -/
theorem encode_delta32_common_body (common d : Nat) (s : State)
    (h0 : s.locals 0 = some (.int IntTy.i32 common))
    (h1 : s.locals 1 = some (.int IntTy.i32 d))
    (hc : common < 4294967296) (hd : d < 4294967296)
    (heq : d = common) :
    ExS Gen.prog s Gen.lspec_crate_encode_delta32.body
      (.ret (some (.int IntTy.u32 0))) s := by
  have hbody := encode_delta32_common common d s h0 h1 hc hd heq
  simp only [Gen.lspec_crate_encode_delta32]
  exact ExS.seq_ret hbody

/-- The 1-byte tail of `lspec_crate_encode_delta32` (code 1): casts `d` to
    `i8`/`u32`, stores its low byte at `out[0]`, and returns `1`. -/
theorem encode_byte1_exs (b : Nat) (blk : Block) (d : Nat) (s : State)
    (h1 : s.locals 1 = some (.int IntTy.i32 d))
    (h2 : s.locals 2 = some (.ptr b 0))
    (hmem : s.mem b = some blk)
    (hro : s.ro = false)
    (hd : d < 4294967296) (hblk : 1 ≤ blk.length) :
    ∃ s', ExS Gen.prog s
        (.seq (.set 3 (.cast IntTy.u32 (.cast IntTy.i8 (.var 1))))
          (.seq (.store (.int IntTy.u8)
                  (.index (.var 2) (.const (.int IntTy.i32 0)) 1)
                  (.cast IntTy.u8 (.var 3)))
            (.ret (some (.cast IntTy.u32 (.const (.int IntTy.i32 1)))))))
      (.ret (some (.int IntTy.u32 1))) s'
      ∧ s'.mem = s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256))) := by
  have hwval : IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d) = d % 256 := by
    by_cases h : 2147483648 ≤ d <;>
      simp [IntTy.wrap, IntTy.i8, IntTy.modulus, IntTy.toInt, IntTy.i32, IntTy.width,
        IntTy.signed, h] <;> omega
  have hwlt : IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d) < 256 := by
    rw [hwval]; exact Nat.mod_lt d (by omega)
  have hs3val : EvE Gen.prog s (.cast IntTy.u32 (.cast IntTy.i8 (.var 1)))
      (.int IntTy.u32 (IntTy.wrap IntTy.u32
        (IntTy.toInt IntTy.i8 (IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d))))) := by
    refine EvE.of_eq 10 (fun f => ?_)
    simp [evalExpr, evalCast, intOf, IntTy.u32, IntTy.i8, IntTy.i32, IntTy.toInt,
      IntTy.modulus, IntTy.wrap, IntTy.width, isPtr, guard, Res.bind_eq,
      Res.bind_ok, h1]
  have hset : ExS Gen.prog s (.set 3 (.cast IntTy.u32 (.cast IntTy.i8 (.var 1)))) .normal
      { s with locals := s.locals.upd 3 (.int IntTy.u32 (IntTy.wrap IntTy.u32 (IntTy.toInt IntTy.i8 (IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d))))) } := ExS.set hs3val
  have haddr : EvE Gen.prog { s with locals := s.locals.upd 3 (.int IntTy.u32 (IntTy.wrap IntTy.u32 (IntTy.toInt IntTy.i8 (IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d))))) } (.index (.var 2) (.const (.int IntTy.i32 0)) 1) (.ptr b 0) := by
    refine EvE.index (EvE.var h2) (EvE.const _) ?_
    simp [ptrAdd, IntTy.i32, IntTy.toInt, IntTy.width, IntTy.modulus, isPtr, hmem]
  have hval : EvE Gen.prog { s with locals := s.locals.upd 3 (.int IntTy.u32 (IntTy.wrap IntTy.u32 (IntTy.toInt IntTy.i8 (IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d))))) } (.var 3) (.int IntTy.u32 (IntTy.wrap IntTy.u32 (IntTy.toInt IntTy.i8 (IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d))))) :=
    EvE.var (by simp [Locals.upd])
  have hu8 : EvE Gen.prog { s with locals := s.locals.upd 3 (.int IntTy.u32 (IntTy.wrap IntTy.u32 (IntTy.toInt IntTy.i8 (IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d))))) } (.cast IntTy.u8 (.var 3)) (.int IntTy.u8 (d % 256)) := by
    refine EvE.of_eq 10 (fun f => ?_)
    simp [evalExpr, evalCast, intOf, IntTy.u8, IntTy.u32, IntTy.toInt, IntTy.modulus,
      IntTy.wrap, IntTy.width, isPtr, guard, Res.bind_eq, Res.bind_ok, hval, Locals.upd,
      hwval, hwlt] <;>
      by_cases h128 : 128 ≤ IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d) <;>
      simp [IntTy.wrap, IntTy.u32, IntTy.i32, IntTy.modulus, IntTy.toInt, IntTy.i8, IntTy.width,
        IntTy.signed, h128, hwval] <;> omega
  have hstore : ExS Gen.prog { s with locals := s.locals.upd 3 (.int IntTy.u32 (IntTy.wrap IntTy.u32 (IntTy.toInt IntTy.i8 (IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d))))) }
      (.store (.int IntTy.u8) (.index (.var 2) (.const (.int IntTy.i32 0)) 1)
        (.cast IntTy.u8 (.var 3))) .normal
      (⟨s.locals.upd 3 (.int IntTy.u32 (IntTy.wrap IntTy.u32 (IntTy.toInt IntTy.i8 (IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d))))), s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256))), s.ro⟩ : State) := by
    refine ExS.store haddr hu8 hro ?_
    exact store_int s.mem b 0 blk hmem IntTy.u8 (d % 256) (by simp; exact hblk)
  have hone : EvE Gen.prog (⟨s.locals.upd 3 (.int IntTy.u32 (IntTy.wrap IntTy.u32 (IntTy.toInt IntTy.i8 (IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d))))), s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256))), s.ro⟩ : State) (.cast IntTy.u32 (.const (.int IntTy.i32 1)))
      (.int IntTy.u32 1) := by
    refine EvE.of_eq 5 (fun f => ?_)
    simp [evalExpr, evalCast, intOf, IntTy.u32, IntTy.i32, IntTy.toInt, IntTy.modulus,
      IntTy.wrap, isPtr]
  have hret : ExS Gen.prog (⟨s.locals.upd 3 (.int IntTy.u32 (IntTy.wrap IntTy.u32 (IntTy.toInt IntTy.i8 (IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d))))), s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256))), s.ro⟩ : State) (.ret (some (.cast IntTy.u32 (.const (.int IntTy.i32 1)))))
      (.ret (some (.int IntTy.u32 1)))
      (⟨s.locals.upd 3 (.int IntTy.u32 (IntTy.wrap IntTy.u32 (IntTy.toInt IntTy.i8 (IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d))))), s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256))), s.ro⟩ : State) := ExS.ret hone
  exact ⟨(⟨s.locals.upd 3 (.int IntTy.u32 (IntTy.wrap IntTy.u32 (IntTy.toInt IntTy.i8 (IntTy.wrap IntTy.i8 (IntTy.toInt IntTy.i32 d))))), s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256))), s.ro⟩ : State),
    ExS.seq hset (ExS.seq hstore hret), rfl⟩

/-- `d >= -128` guard (signed) for code 1. -/
theorem enc_ge_eval (d : Nat) (s : State)
    (h1 : s.locals 1 = some (.int IntTy.i32 d)) :
    EvE Gen.prog s
      (.bin .ge (some IntTy.i32) (.var 1) (.un .neg IntTy.i32 (.const (.int IntTy.i32 128))))
      (boolVal (decide (-128 ≤ IntTy.toInt IntTy.i32 d))) := by
  refine EvE.of_eq 10 (fun f => ?_)
  have hin : IntTy.inRange IntTy.i32 (-128) = true := by decide
  simp [evalExpr, evalBin, evalBinInt, binInt, evalUn, intOf, IntTy.i32, IntTy.toInt,
    IntTy.modulus, IntTy.wrap, IntTy.inRange, IntTy.minVal, IntTy.maxVal, IntTy.width,
    IntTy.signed, isPtr, guard, Res.bind_eq, Res.bind_ok, h1, arith, hin]

/-- `d <= 127` guard (signed) for code 1. -/
theorem enc_le_eval (d : Nat) (s : State)
    (h1 : s.locals 1 = some (.int IntTy.i32 d)) :
    EvE Gen.prog s
      (.bin .le (some IntTy.i32) (.var 1) (.const (.int IntTy.i32 127)))
      (boolVal (decide (IntTy.toInt IntTy.i32 d ≤ 127))) := by
  refine EvE.of_eq 10 (fun f => ?_)
  simp [evalExpr, evalBin, evalBinInt, binInt, intOf, IntTy.i32, IntTy.toInt,
    IntTy.modulus, isPtr, guard, Res.bind_eq, Res.bind_ok, h1]

/-- **Whole-function `callFunc` for `encode_delta32` (code 1 branch).**
    `d ≠ common` and `-128 ≤ d ≤ 127` (signed) pick the 1-byte store. -/
theorem encode_delta32_call (common d b : Nat) (blk : Block) (m : Mem)
    (hc : common < 4294967296) (hd : d < 4294967296)
    (hne : d ≠ common)
    (hge : (-128 : Int) ≤ IntTy.toInt IntTy.i32 d)
    (hle : IntTy.toInt IntTy.i32 d ≤ 127)
    (hmem : m b = some blk) (hblk : 1 ≤ blk.length) :
    ∃ K, ∀ n, K ≤ n →
      callFunc Gen.prog n Gen.fid_lspec_crate_encode_delta32
        [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0] m
      = .ok (some (.int IntTy.u32 1),
          m.upd b (splice blk 0 (encodeLE 1 (d % 256)))) := by
  have hf0 : frameLocals [0, 1, 2]
      [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0] 0
      = some (.int IntTy.i32 common) := rfl
  have hf1 : frameLocals [0, 1, 2]
      [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0] 1
      = some (.int IntTy.i32 d) := rfl
  have hf2 : frameLocals [0, 1, 2]
      [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0] 2
      = some (.ptr b 0) := rfl
  let s0 : State := ⟨frameLocals [0, 1, 2]
      [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0], m, false⟩
  have hneEv : EvE Gen.prog s0
      (.bin .eq (some IntTy.i32) (.var 1) (.var 0)) (boolVal false) := by
    have h := enc_eq_eval common d s0 hf0 hf1
    have hdec : decide (IntTy.toInt IntTy.i32 d = IntTy.toInt IntTy.i32 common) = false := by
      rw [decide_eq_false_iff_not]
      intro heq
      exact hne (toInt_i32_inj hd hc heq)
    rwa [hdec] at h
  have hgeEv : EvE Gen.prog s0
      (.bin .ge (some IntTy.i32) (.var 1)
        (.un .neg IntTy.i32 (.const (.int IntTy.i32 128)))) (boolVal true) := by
    have h := enc_ge_eval d s0 hf1
    have hdec : decide (-128 ≤ IntTy.toInt IntTy.i32 d) = true := by
      rw [decide_eq_true_eq]
      exact hge
    rwa [hdec] at h
  have hleEv : EvE Gen.prog s0
      (.bin .le (some IntTy.i32) (.var 1) (.const (.int IntTy.i32 127)))
      (boolVal true) := by
    have h := enc_le_eval d s0 hf1
    have hdec : decide (IntTy.toInt IntTy.i32 d ≤ 127) = true := by
      rw [decide_eq_true_eq]
      exact hle
    rwa [hdec] at h
  obtain ⟨s'', hfrag, hmem2⟩ := encode_byte1_exs b blk d s0 hf1 hf2 hmem rfl hd hblk
  have hWhole : ExS Gen.prog s0 Gen.lspec_crate_encode_delta32.body
      (.ret (some (.int IntTy.u32 1))) s'' := by
    simp only [Gen.lspec_crate_encode_delta32]
    refine ExS.seq (ExS.ite hneEv (truthy_boolVal false) ExS.skip) ?_
    refine ExS.seq_ret ?_
    refine ExS.ite hgeEv (truthy_boolVal true) ?_
    exact ExS.ite hleEv (truthy_boolVal true) hfrag
  have hf : Gen.prog Gen.fid_lspec_crate_encode_delta32
      = some Gen.lspec_crate_encode_delta32 := by
    simp [Gen.prog, Gen.fid_lspec_crate_encode_delta32]
  have hlen : Gen.lspec_crate_encode_delta32.params.length
      = (([.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0] : List Val).length) := by
    simp [Gen.lspec_crate_encode_delta32]
  have hEx' : ExS Gen.prog
      (⟨frameLocals Gen.lspec_crate_encode_delta32.params
        [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0], m, false⟩ : State)
      Gen.lspec_crate_encode_delta32.body
      (.ret (some (.int IntTy.u32 1))) s'' := by
    simpa [Gen.lspec_crate_encode_delta32] using hWhole
  have hcall := callFunc_of_ExS hf hlen hEx'
  obtain ⟨K, hK⟩ := hcall
  refine ⟨K, fun n hn => ?_⟩
  have h := hK n hn
  rwa [show s''.mem = m.upd b (splice blk 0 (encodeLE 1 (d % 256))) from hmem2] at h

/-- `d >= -32768` guard (signed) for code 2. -/
theorem enc_ge16_eval (d : Nat) (s : State)
    (h1 : s.locals 1 = some (.int IntTy.i32 d)) :
    EvE Gen.prog s
      (.bin .ge (some IntTy.i32) (.var 1) (.un .neg IntTy.i32 (.const (.int IntTy.i32 32768))))
      (boolVal (decide (-32768 ≤ IntTy.toInt IntTy.i32 d))) := by
  refine EvE.of_eq 10 (fun f => ?_)
  have hin : IntTy.inRange IntTy.i32 (-32768) = true := by decide
  simp [evalExpr, evalBin, evalBinInt, binInt, evalUn, intOf, IntTy.i32, IntTy.toInt,
    IntTy.modulus, IntTy.wrap, IntTy.inRange, IntTy.minVal, IntTy.maxVal, IntTy.width,
    IntTy.signed, isPtr, guard, Res.bind_eq, Res.bind_ok, h1, arith, hin]

/-- `d <= 32767` guard (signed) for code 2. -/
theorem enc_le16_eval (d : Nat) (s : State)
    (h1 : s.locals 1 = some (.int IntTy.i32 d)) :
    EvE Gen.prog s
      (.bin .le (some IntTy.i32) (.var 1) (.const (.int IntTy.i32 32767)))
      (boolVal (decide (IntTy.toInt IntTy.i32 d ≤ 32767))) := by
  refine EvE.of_eq 10 (fun f => ?_)
  simp [evalExpr, evalBin, evalBinInt, binInt, intOf, IntTy.i32, IntTy.toInt,
    IntTy.modulus, isPtr, guard, Res.bind_eq, Res.bind_ok, h1]

/-- The two representation bytes of `encodeLE 2 y`. -/
theorem encodeLE2_eq (y : Nat) :
    encodeLE 2 y = encodeLE 1 (y % 256) ++ encodeLE 1 ((y / 256) % 256) := by
  simp [encodeLE, Nat.mod_mod]

/-- The 2-byte tail of `lspec_crate_encode_delta32` (code 2): casts `d` to a
    16-bit value and stores its two little-endian bytes before returning
    `2`. -/
theorem encode_byte2_exs (b : Nat) (blk : Block) (d : Nat) (s : State)
    (h1 : s.locals 1 = some (.int IntTy.i32 d))
    (h2 : s.locals 2 = some (.ptr b 0))
    (hmem : s.mem b = some blk)
    (hro : s.ro = false)
    (hd : d < 4294967296) (hblk : 2 ≤ blk.length) :
    ∃ s', ExS Gen.prog s
        (.seq (.set 4 (.cast IntTy.u16 (.cast IntTy.i16 (.var 1))))
          (.seq (.store (.int IntTy.u8)
                  (.index (.var 2) (.const (.int IntTy.i32 0)) 1)
                  (.cast IntTy.u8 (.bin .band (some IntTy.i32)
                    (.cast IntTy.i32 (.var 4)) (.const (.int IntTy.i32 255)))))
            (.seq (.store (.int IntTy.u8)
                    (.index (.var 2) (.const (.int IntTy.i32 1)) 1)
                    (.cast IntTy.u8 (.bin .band (some IntTy.i32)
                      (.bin .shr (some IntTy.i32)
                        (.cast IntTy.i32 (.var 4)) (.const (.int IntTy.i32 8)))
                      (.const (.int IntTy.i32 255)))))
              (.ret (some (.cast IntTy.u32 (.const (.int IntTy.i32 2))))))))
      (.ret (some (.int IntTy.u32 2))) s'
      ∧ s'.mem = s.mem.upd b (splice blk 0 (encodeLE 2 (d % 65536))) := by
  let y : Nat := d % 65536
  have hy : y = d % 65536 := rfl
  have hwval : IntTy.wrap IntTy.i16 (IntTy.toInt IntTy.i32 d) = y := by
    by_cases h : 2147483648 ≤ d <;>
      simp [IntTy.wrap, IntTy.i16, IntTy.modulus, IntTy.toInt, IntTy.i32, IntTy.width,
        IntTy.signed, h, hy] <;> omega
  have hwlt : IntTy.wrap IntTy.i16 (IntTy.toInt IntTy.i32 d) < 65536 := by
    rw [hwval, hy]; exact Nat.mod_lt d (by omega)
  have hs4val : EvE Gen.prog s (.cast IntTy.u16 (.cast IntTy.i16 (.var 1)))
      (.int IntTy.u16 y) := by
    refine EvE.of_eq 10 (fun f => ?_)
    simp [evalExpr, evalCast, intOf, IntTy.u16, IntTy.i16, IntTy.i32, IntTy.toInt,
      IntTy.modulus, IntTy.wrap, IntTy.width, isPtr, guard, Res.bind_eq,
      Res.bind_ok, h1, hwval, hwlt] <;>
      by_cases h32768 : 32768 ≤ IntTy.wrap IntTy.i16 (IntTy.toInt IntTy.i32 d) <;>
      omega
  have hset : ExS Gen.prog s (.set 4 (.cast IntTy.u16 (.cast IntTy.i16 (.var 1)))) .normal
      { s with locals := s.locals.upd 4 (.int IntTy.u16 y) } := ExS.set hs4val
  have haddr0 : EvE Gen.prog { s with locals := s.locals.upd 4 (.int IntTy.u16 y) }
      (.index (.var 2) (.const (.int IntTy.i32 0)) 1) (.ptr b 0) := by
    refine EvE.index (EvE.var h2) (EvE.const _) ?_
    simp [ptrAdd, IntTy.i32, IntTy.toInt, IntTy.width, IntTy.modulus, isPtr, hmem]
  have hval4 : EvE Gen.prog { s with locals := s.locals.upd 4 (.int IntTy.u16 y) }
      (.var 4) (.int IntTy.u16 y) := EvE.var (by simp [Locals.upd])
  have hlow : EvE Gen.prog { s with locals := s.locals.upd 4 (.int IntTy.u16 y) }
      (.cast IntTy.u8 (.bin .band (some IntTy.i32)
        (.cast IntTy.i32 (.var 4)) (.const (.int IntTy.i32 255))))
      (.int IntTy.u8 (y % 256)) := by
    have hcast : EvE Gen.prog { s with locals := s.locals.upd 4 (.int IntTy.u16 y) }
        (.cast IntTy.i32 (.var 4)) (.int IntTy.i32 y) :=
      EvE.cast hval4 (by
        simp [evalCast, IntTy.i32, IntTy.u16, IntTy.signed, IntTy.modulus,
          Nat.mod_eq_of_lt (show y < 4294967296 by omega)])
    have hband : EvE Gen.prog { s with locals := s.locals.upd 4 (.int IntTy.u16 y) }
        (.bin .band (some IntTy.i32) (.cast IntTy.i32 (.var 4))
          (.const (.int IntTy.i32 255)))
        (.int IntTy.i32 (y % 256)) :=
      EvE.bin hcast (EvE.const _) (by
        simp [evalBin, evalBinInt, binInt, intOf, IntTy.i32, IntTy.signed, isPtr,
          IntTy.width, IntTy.modulus, and255_mod])
    exact EvE.cast hband (by
      simp [evalCast, IntTy.u8, IntTy.i32, IntTy.signed, IntTy.modulus, IntTy.wrap,
        IntTy.toInt, IntTy.width, Nat.mod_mod] <;>
        by_cases hthr : 2147483648 ≤ y % 256 <;> omega)
  have hstore0 : ExS Gen.prog { s with locals := s.locals.upd 4 (.int IntTy.u16 y) }
      (.store (.int IntTy.u8) (.index (.var 2) (.const (.int IntTy.i32 0)) 1)
        (.cast IntTy.u8 (.bin .band (some IntTy.i32)
          (.cast IntTy.i32 (.var 4)) (.const (.int IntTy.i32 255))))) .normal
      (⟨s.locals.upd 4 (.int IntTy.u16 y), s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256))), s.ro⟩ : State) := by
    refine ExS.store haddr0 hlow hro ?_
    exact store_int s.mem b 0 blk hmem IntTy.u8 (y % 256) (by
      simp [IntTy.bytes, IntTy.u8, IntTy.width]; omega)
  have haddr1 : EvE Gen.prog
      (⟨s.locals.upd 4 (.int IntTy.u16 y), s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256))), s.ro⟩ : State)
      (.index (.var 2) (.const (.int IntTy.i32 1)) 1) (.ptr b 1) := by
    have hloc2 : (⟨s.locals.upd 4 (.int IntTy.u16 y), s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256))), s.ro⟩ : State).locals 2
        = some (.ptr b 0) := by
      simp [Locals.upd, h2]
    have hmem2 : (s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256)))) b
        = some (splice blk 0 (encodeLE 1 (y % 256))) := by
      simp [Mem.upd]
    have hlen : (splice blk 0 (encodeLE 1 (y % 256))).length = blk.length := by
      rw [splice_length blk 0 (encodeLE 1 (y % 256)) (by
        simp [IntTy.bytes, IntTy.u8, IntTy.width]; omega)]
    have hblkI : (1 : Int) ≤ ((blk.length : Nat) : Int) := by omega
    refine EvE.index (EvE.var hloc2) (EvE.const _) ?_
    simp [ptrAdd, IntTy.i32, IntTy.toInt, IntTy.width, IntTy.modulus, isPtr, hmem2, hblk, hlen, hblkI]
  have hhigh : EvE Gen.prog
      (⟨s.locals.upd 4 (.int IntTy.u16 y), s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256))), s.ro⟩ : State)
      (.cast IntTy.u8 (.bin .band (some IntTy.i32)
        (.bin .shr (some IntTy.i32) (.cast IntTy.i32 (.var 4)) (.const (.int IntTy.i32 8)))
        (.const (.int IntTy.i32 255))))
      (.int IntTy.u8 ((y / 256) % 256)) := by
    have hval4' : EvE Gen.prog
        (⟨s.locals.upd 4 (.int IntTy.u16 y), s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256))), s.ro⟩ : State)
        (.var 4) (.int IntTy.u16 y) := EvE.var (by simp [Locals.upd])
    have hcast : EvE Gen.prog
        (⟨s.locals.upd 4 (.int IntTy.u16 y), s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256))), s.ro⟩ : State)
        (.cast IntTy.i32 (.var 4)) (.int IntTy.i32 y) :=
      EvE.cast hval4' (by
        simp [evalCast, IntTy.i32, IntTy.u16, IntTy.signed, IntTy.modulus,
          Nat.mod_eq_of_lt (show y < 4294967296 by omega)])
    have hshr : EvE Gen.prog
        (⟨s.locals.upd 4 (.int IntTy.u16 y), s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256))), s.ro⟩ : State)
        (.bin .shr (some IntTy.i32) (.cast IntTy.i32 (.var 4)) (.const (.int IntTy.i32 8)))
        (.int IntTy.i32 (y / 256)) :=
      EvE.bin hcast (EvE.const _)
        (evalShr8 y (by omega))
    have hband : EvE Gen.prog
        (⟨s.locals.upd 4 (.int IntTy.u16 y), s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256))), s.ro⟩ : State)
        (.bin .band (some IntTy.i32)
          (.bin .shr (some IntTy.i32) (.cast IntTy.i32 (.var 4)) (.const (.int IntTy.i32 8)))
          (.const (.int IntTy.i32 255)))
        (.int IntTy.i32 ((y / 256) % 256)) :=
      EvE.bin hshr (EvE.const _) (by
        simp [evalBin, evalBinInt, binInt, intOf, IntTy.i32, IntTy.signed, isPtr,
          IntTy.width, IntTy.modulus, and255_mod])
    exact EvE.cast hband (by
      simp [evalCast, IntTy.u8, IntTy.i32, IntTy.signed, IntTy.modulus, IntTy.wrap,
        IntTy.toInt, IntTy.width, Nat.mod_mod] <;>
        by_cases hthr : 2147483648 ≤ y / 256 % 256 <;> omega)
  have hstore1 : ExS Gen.prog
      (⟨s.locals.upd 4 (.int IntTy.u16 y), s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256))), s.ro⟩ : State)
      (.store (.int IntTy.u8) (.index (.var 2) (.const (.int IntTy.i32 1)) 1)
        (.cast IntTy.u8 (.bin .band (some IntTy.i32)
          (.bin .shr (some IntTy.i32) (.cast IntTy.i32 (.var 4)) (.const (.int IntTy.i32 8)))
          (.const (.int IntTy.i32 255))))) .normal
      (⟨s.locals.upd 4 (.int IntTy.u16 y),
        (s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (y % 256))) 1 (encodeLE 1 ((y / 256) % 256))),
        s.ro⟩ : State) := by
    refine ExS.store haddr1 hhigh hro ?_
    have hmem1 : (s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256)))) b
        = some (splice blk 0 (encodeLE 1 (y % 256))) := by
      simp [Mem.upd]
    have hlen1 : (splice blk 0 (encodeLE 1 (y % 256))).length = blk.length := by
      rw [splice_length blk 0 (encodeLE 1 (y % 256)) (by simp; omega)]
    exact store_int _ b 1 _ hmem1 IntTy.u8 ((y / 256) % 256) (by
      simp [IntTy.bytes, IntTy.u8, IntTy.width, hlen1, hblk])
  have hfinal : splice (splice blk 0 (encodeLE 1 (y % 256))) 1 (encodeLE 1 ((y / 256) % 256))
      = splice blk 0 (encodeLE 2 y) := by
    rw [encodeLE2_eq (y := y)]
    simpa [encodeLE_length] using splice_append blk 0 (encodeLE 1 (y % 256)) (encodeLE 1 ((y / 256) % 256)) (by simp [hblk])
  have hret : ExS Gen.prog
      (⟨s.locals.upd 4 (.int IntTy.u16 y),
        (s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (y % 256))) 1 (encodeLE 1 ((y / 256) % 256))),
        s.ro⟩ : State)
      (.ret (some (.cast IntTy.u32 (.const (.int IntTy.i32 2)))))
      (.ret (some (.int IntTy.u32 2)))
      (⟨s.locals.upd 4 (.int IntTy.u16 y),
        (s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (y % 256))) 1 (encodeLE 1 ((y / 256) % 256))),
        s.ro⟩ : State) := by
    have hone : EvE Gen.prog
        (⟨s.locals.upd 4 (.int IntTy.u16 y),
          (s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256)))).upd b
            (splice (splice blk 0 (encodeLE 1 (y % 256))) 1 (encodeLE 1 ((y / 256) % 256))),
          s.ro⟩ : State)
        (.cast IntTy.u32 (.const (.int IntTy.i32 2))) (.int IntTy.u32 2) := by
      refine EvE.of_eq 5 (fun f => ?_)
      simp [evalExpr, evalCast, intOf, IntTy.u32, IntTy.i32, IntTy.toInt, IntTy.modulus,
        IntTy.wrap, isPtr]
    exact ExS.ret hone
  have hmemfinal : (s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256)))).upd b
      (splice (splice blk 0 (encodeLE 1 (y % 256))) 1 (encodeLE 1 ((y / 256) % 256)))
      = s.mem.upd b (splice blk 0 (encodeLE 2 y)) := by
    funext x
    by_cases hx : x = b
    · simp [Mem.upd, hx, hfinal]
    · simp [Mem.upd, hx]
  exact ⟨(⟨s.locals.upd 4 (.int IntTy.u16 y),
      (s.mem.upd b (splice blk 0 (encodeLE 1 (y % 256)))).upd b
        (splice (splice blk 0 (encodeLE 1 (y % 256))) 1 (encodeLE 1 ((y / 256) % 256))),
      s.ro⟩ : State),
    ExS.seq hset (ExS.seq hstore0 (ExS.seq hstore1 hret)), hmemfinal⟩

/-- **Whole-function `callFunc` for `encode_delta32` (code 2 branch).**
    `d ≠ common`, `-128 ≤ d` fails (so code 1 is skipped), and
    `-32768 ≤ d ≤ 32767` selects the 2-byte store. -/
theorem encode_delta32_call2 (common d b : Nat) (blk : Block) (m : Mem)
    (hc : common < 4294967296) (hd : d < 4294967296)
    (hne : d ≠ common)
    (hnot1 : ¬ ((-128 : Int) ≤ IntTy.toInt IntTy.i32 d))
    (hge2 : (-32768 : Int) ≤ IntTy.toInt IntTy.i32 d)
    (hle2 : IntTy.toInt IntTy.i32 d ≤ 32767)
    (hmem : m b = some blk) (hblk : 2 ≤ blk.length) :
    ∃ K, ∀ n, K ≤ n →
      callFunc Gen.prog n Gen.fid_lspec_crate_encode_delta32
        [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0] m
      = .ok (some (.int IntTy.u32 2),
          m.upd b (splice blk 0 (encodeLE 2 (d % 65536)))) := by
  have hf0 : frameLocals [0, 1, 2]
      [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0] 0
      = some (.int IntTy.i32 common) := rfl
  have hf1 : frameLocals [0, 1, 2]
      [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0] 1
      = some (.int IntTy.i32 d) := rfl
  have hf2 : frameLocals [0, 1, 2]
      [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0] 2
      = some (.ptr b 0) := rfl
  let s0 : State := ⟨frameLocals [0, 1, 2]
      [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0], m, false⟩
  have hneEv : EvE Gen.prog s0
      (.bin .eq (some IntTy.i32) (.var 1) (.var 0)) (boolVal false) := by
    have h := enc_eq_eval common d s0 hf0 hf1
    have hdec : decide (IntTy.toInt IntTy.i32 d = IntTy.toInt IntTy.i32 common) = false := by
      rw [decide_eq_false_iff_not]
      intro heq
      exact hne (toInt_i32_inj hd hc heq)
    rwa [hdec] at h
  have hge128Ev : EvE Gen.prog s0
      (.bin .ge (some IntTy.i32) (.var 1)
        (.un .neg IntTy.i32 (.const (.int IntTy.i32 128)))) (boolVal false) := by
    have h := enc_ge_eval d s0 hf1
    have hdec : decide (-128 ≤ IntTy.toInt IntTy.i32 d) = false := by
      rw [decide_eq_false_iff_not]
      exact hnot1
    rwa [hdec] at h
  have hge32768Ev : EvE Gen.prog s0
      (.bin .ge (some IntTy.i32) (.var 1)
        (.un .neg IntTy.i32 (.const (.int IntTy.i32 32768)))) (boolVal true) := by
    have h := enc_ge16_eval d s0 hf1
    have hdec : decide (-32768 ≤ IntTy.toInt IntTy.i32 d) = true := by
      rw [decide_eq_true_eq]
      exact hge2
    rwa [hdec] at h
  have hle32767Ev : EvE Gen.prog s0
      (.bin .le (some IntTy.i32) (.var 1) (.const (.int IntTy.i32 32767)))
      (boolVal true) := by
    have h := enc_le16_eval d s0 hf1
    have hdec : decide (IntTy.toInt IntTy.i32 d ≤ 32767) = true := by
      rw [decide_eq_true_eq]
      exact hle2
    rwa [hdec] at h
  obtain ⟨s'', hfrag, hmem2⟩ := encode_byte2_exs b blk d s0 hf1 hf2 hmem rfl hd hblk
  have hWhole : ExS Gen.prog s0 Gen.lspec_crate_encode_delta32.body
      (.ret (some (.int IntTy.u32 2))) s'' := by
    simp only [Gen.lspec_crate_encode_delta32]
    refine ExS.seq (ExS.ite hneEv (truthy_boolVal false) ExS.skip) ?_
    refine ExS.seq (ExS.ite hge128Ev (truthy_boolVal false) ExS.skip) ?_
    refine ExS.seq_ret ?_
    refine ExS.ite hge32768Ev (truthy_boolVal true) ?_
    exact ExS.ite hle32767Ev (truthy_boolVal true) hfrag
  have hf : Gen.prog Gen.fid_lspec_crate_encode_delta32
      = some Gen.lspec_crate_encode_delta32 := by
    simp [Gen.prog, Gen.fid_lspec_crate_encode_delta32]
  have hlen : Gen.lspec_crate_encode_delta32.params.length
      = (([.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0] : List Val).length) := by
    simp [Gen.lspec_crate_encode_delta32]
  have hEx' : ExS Gen.prog
      (⟨frameLocals Gen.lspec_crate_encode_delta32.params
        [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0], m, false⟩ : State)
      Gen.lspec_crate_encode_delta32.body
      (.ret (some (.int IntTy.u32 2))) s'' := by
    simpa [Gen.lspec_crate_encode_delta32] using hWhole
  have hcall := callFunc_of_ExS hf hlen hEx'
  obtain ⟨K, hK⟩ := hcall
  refine ⟨K, fun n hn => ?_⟩
  have h := hK n hn
  rwa [show s''.mem = m.upd b (splice blk 0 (encodeLE 2 (d % 65536))) from hmem2] at h

end UsdSpecC.Proofs

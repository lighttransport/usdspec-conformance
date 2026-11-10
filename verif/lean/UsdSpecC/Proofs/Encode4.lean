/-
  Crate delta-codec 4-byte tail (code 3) of `lspec_crate_encode_delta32`,
  mirroring `Encode.lean` (codes 1 and 2) and tinygltf `Proofs/Wr32.lean`
  (`store_int`, `splice`). Landed: the generalized 4-byte tail fragment
  (`set` u32 cast + four u8 stores + `ret 3`, postcondition
  `splice blk 0 (encodeLE 4 d)`) via `encodeLE4_eq2el`/`splice_bytes4`,
  and whole-function `encode_delta32_call3` for the code-3 branch through
  the two guard-skip hypotheses.
-/
import UsdSpecC.Gen
import UsdSpecC.Logic
import UsdSpecC.Hoare
import UsdSpecC.Proofs.Encode
import UsdSpecC.Splice

namespace UsdSpecC.Proofs

open UsdSpecC

set_option linter.unusedSimpArgs false
set_option linter.unusedVariables false
set_option maxRecDepth 4000
set_option linter.deprecated false

/-- The low byte of `n` is just its remainder modulo 256 (u32 form). -/
theorem and255_mod4 (n : Nat) : n &&& 255 = n % 256 := by
  simpa using Nat.and_two_pow_sub_one_eq_mod n 8

/-- Unsigned `u32` wrap of an `i32` representation `< 2^32` is exact. -/
theorem wrap_u32_i32 (d : Nat) (hd : d < 4294967296) :
    IntTy.wrap IntTy.u32 (IntTy.toInt IntTy.i32 d) = d := by
  by_cases h : 2147483648 ≤ d <;>
    simp [IntTy.wrap, IntTy.u32, IntTy.modulus, IntTy.toInt, IntTy.i32,
      IntTy.width, IntTy.signed, h] <;> omega

/-- The generated body's byte mask `0xff` is `(uint32_t)255`. -/
theorem evCast255 (s : State) :
    EvE Gen.prog s (.cast IntTy.u32 (.const (.int IntTy.i32 255))) (.int IntTy.u32 255) := by
  refine EvE.of_eq 5 (fun f => ?_)
  simp [evalExpr, evalCast, intOf, IntTy.u32, IntTy.i32, IntTy.toInt, IntTy.modulus,
    IntTy.wrap, isPtr, Res.pure_eq, Res.bind_eq, Res.bind_ok]

/-- Evaluation of an unsigned 32-bit right shift by `k` bits. -/
theorem evalShrU (x k : Nat) (hx : x < 4294967296) (hk : k < 32) :
    evalBin .shr (some IntTy.u32) (.int IntTy.u32 x) (.int IntTy.i32 k)
      = .ok (.int IntTy.u32 (x / 2 ^ k)) := by
  have hx' : IntTy.toInt IntTy.u32 x = (x : Int) := by
    simp [IntTy.u32, IntTy.toInt, IntTy.signed]
  have hk' : IntTy.toInt IntTy.i32 k = (k : Int) := by
    simp only [IntTy.i32, IntTy.modulus, IntTy.toInt]
    split <;> omega
  simp [evalBin, evalBinInt, binInt, isPtr, intOf, IntTy.u32, IntTy.modulus,
    Res.pure_eq, Res.bind_eq, Res.bind_ok, UsdSpecC.guard,
    hx', hk', show (0 : Int) ≤ (0 + (k : Int)) from by omega,
    show (k : Int) < 32 from by omega, hx, hk]

/-- Evaluation of a u32 band with `255` (low-byte mask). -/
theorem evalBand255 (d : Nat) :
    evalBin .band (some IntTy.u32) (.int IntTy.u32 d) (.int IntTy.u32 255)
      = .ok (.int IntTy.u32 (d % 256)) := by
  simp [evalBin, evalBinInt, binInt, isPtr, intOf, IntTy.u32, IntTy.signed,
    IntTy.modulus, and255_mod4, Res.pure_eq, Res.bind_eq, Res.bind_ok]

/-- `encodeLE 4 y` splits into two `encodeLE 2` halves. -/
theorem encodeLE4_eq2el (y : Nat) :
    encodeLE 4 y = encodeLE 2 y ++ encodeLE 2 (y / 65536) := by
  have e1 : y / 256 / 256 = y / 65536 := by omega
  have e2 : y / 256 / 256 / 256 = y / 65536 / 256 := by omega
  simp [encodeLE, Nat.mod_mod, e1, e2]

/-- Fold two adjacent single-byte writes into one 2-byte write. -/
theorem foldPair (Y : Block) (o r : Nat) (h : o + 2 ≤ Y.length) :
    splice Y o (encodeLE 2 r)
      = splice (splice Y o (encodeLE 1 (r % 256)))
          (o + (encodeLE 1 (r % 256)).length)
          (encodeLE 1 ((r / 256) % 256)) := by
  rw [encodeLE2_eq (y := r)]
  exact (splice_append Y o (encodeLE 1 (r % 256)) (encodeLE 1 ((r / 256) % 256))
    (by simp only [encodeLE_length]; omega)).symm

/-- Fold two adjacent 2-byte writes into one 4-byte write. -/
theorem foldPair4 (Y : Block) (o r : Nat) (h : o + 4 ≤ Y.length) :
    splice Y o (encodeLE 4 r)
      = splice (splice Y o (encodeLE 2 r)) (o + (encodeLE 2 r).length)
          (encodeLE 2 (r / 65536)) := by
  rw [encodeLE4_eq2el]
  exact (splice_append Y o (encodeLE 2 r) (encodeLE 2 (r / 65536))
    (by simp only [encodeLE_length]; omega)).symm

/-- Four adjacent u8 writes compose into one 4-byte write. -/
theorem splice_bytes4 (blk : Block) (y : Nat) (h : 4 ≤ blk.length) :
    splice (splice (splice (splice blk 0 (encodeLE 1 (y % 256)))
        1 (encodeLE 1 ((y / 256) % 256)))
      2 (encodeLE 1 ((y / 65536) % 256)))
    3 (encodeLE 1 ((y / 16777216) % 256))
      = splice blk 0 (encodeLE 4 y) := by
  have h2 : 0 + 2 ≤ blk.length := by omega
  have hlf0 : (splice blk 0 (encodeLE 1 (y % 256))).length = blk.length :=
    splice_length blk 0 (encodeLE 1 (y % 256)) (by simp only [encodeLE_length]; omega)
  have hlf1 : (splice (splice blk 0 (encodeLE 1 (y % 256)))
      (0 + (encodeLE 1 (y % 256)).length) (encodeLE 1 ((y / 256) % 256))).length
      = blk.length := by
    rw [splice_length (blk := splice blk 0 (encodeLE 1 (y % 256)))
      (o := 0 + (encodeLE 1 (y % 256)).length) (bs := encodeLE 1 ((y / 256) % 256))
      (by rw [hlf0]; simp only [encodeLE_length]; omega), hlf0]
  have h3 : 0 + (encodeLE 2 y).length + 2
      ≤ (splice (splice blk 0 (encodeLE 1 (y % 256)))
          (0 + (encodeLE 1 (y % 256)).length) (encodeLE 1 ((y / 256) % 256))).length := by
    rw [hlf1]; simp only [encodeLE_length]; omega
  rw [foldPair4 blk 0 y h,
    foldPair (Y := blk) (o := 0) (r := y) h2,
    foldPair (Y := splice (splice blk 0 (encodeLE 1 (y % 256)))
        (0 + (encodeLE 1 (y % 256)).length) (encodeLE 1 ((y / 256) % 256)))
      (o := 0 + (encodeLE 2 y).length) (r := y / 65536) h3,
    show (y / 65536) / 256 = y / 16777216 from by omega]
  rfl

/-- The 4-byte tail of `lspec_crate_encode_delta32` (code 3): casts `d` to
    `u32` and stores its four little-endian bytes before returning `3`. -/
theorem encode_byte4_exs (b : Nat) (blk : Block) (d : Nat) (s : State)
    (h1 : s.locals 1 = some (.int IntTy.i32 d))
    (h2 : s.locals 2 = some (.ptr b 0))
    (hmem : s.mem b = some blk)
    (hro : s.ro = false)
    (hd : d < 4294967296) (hblk : 4 ≤ blk.length) :
    ∃ s', ExS Gen.prog s
        (.seq (.set 3 (.cast IntTy.u32 (.var 1)))
          (.seq (.store (.int IntTy.u8) (.index (.var 2) (.const (.int IntTy.i32 0)) 1)
                  (.cast IntTy.u8 (.bin .band (some IntTy.u32) (.var 3)
                    (.cast IntTy.u32 (.const (.int IntTy.i32 255))))))
            (.seq (.store (.int IntTy.u8) (.index (.var 2) (.const (.int IntTy.i32 1)) 1)
                    (.cast IntTy.u8 (.bin .band (some IntTy.u32)
                      (.bin .shr (some IntTy.u32) (.var 3) (.const (.int IntTy.i32 8)))
                      (.cast IntTy.u32 (.const (.int IntTy.i32 255))))))
              (.seq (.store (.int IntTy.u8) (.index (.var 2) (.const (.int IntTy.i32 2)) 1)
                      (.cast IntTy.u8 (.bin .band (some IntTy.u32)
                        (.bin .shr (some IntTy.u32) (.var 3) (.const (.int IntTy.i32 16)))
                        (.cast IntTy.u32 (.const (.int IntTy.i32 255))))))
                (.seq (.store (.int IntTy.u8) (.index (.var 2) (.const (.int IntTy.i32 3)) 1)
                        (.cast IntTy.u8 (.bin .band (some IntTy.u32)
                          (.bin .shr (some IntTy.u32) (.var 3) (.const (.int IntTy.i32 24)))
                          (.cast IntTy.u32 (.const (.int IntTy.i32 255))))))
                  (.ret (some (.cast IntTy.u32 (.const (.int IntTy.i32 3))))))))))
      (.ret (some (.int IntTy.u32 3))) s'
      ∧ s'.mem = s.mem.upd b (splice blk 0 (encodeLE 4 d)) := by
  have hw := wrap_u32_i32 d hd
  -- Nested write blocks (each store peels off one byte), spelled out inline.
  have hlf0 : (splice blk 0 (encodeLE 1 (d % 256))).length = blk.length :=
    splice_length blk 0 (encodeLE 1 (d % 256)) (by rw [encodeLE_length]; omega)
  have hlf1 : (splice (splice blk 0 (encodeLE 1 (d % 256)))
      1 (encodeLE 1 ((d / 256) % 256))).length = blk.length := by
    rw [splice_length (splice blk 0 (encodeLE 1 (d % 256)))
      1 (encodeLE 1 ((d / 256) % 256)) (by rw [encodeLE_length, hlf0]; omega), hlf0]
  have hlf2 : (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
      1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256))).length
      = blk.length := by
    rw [splice_length (splice (splice blk 0 (encodeLE 1 (d % 256)))
      1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256))
      (by rw [encodeLE_length, hlf1]; omega), hlf1]
  have hlf3 : (splice (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
      1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256)))
      3 (encodeLE 1 ((d / 16777216) % 256))).length = blk.length := by
    rw [splice_length (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
      1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256)))
      3 (encodeLE 1 ((d / 16777216) % 256)) (by rw [encodeLE_length, hlf2]; omega), hlf2]
  -- set 3 (u32 cast)
  have hs3val : EvE Gen.prog s (.cast IntTy.u32 (.var 1)) (.int IntTy.u32 d) := by
    refine EvE.of_eq 10 (fun f => ?_)
    simp [evalExpr, evalCast, intOf, IntTy.u32, IntTy.i32, IntTy.toInt, IntTy.modulus,
      IntTy.wrap, isPtr, guard, Res.bind_eq, Res.bind_ok, h1, hw] <;> omega
  have hset : ExS Gen.prog s (.set 3 (.cast IntTy.u32 (.var 1))) .normal
      (⟨s.locals.upd 3 (.int IntTy.u32 d), s.mem, s.ro⟩ : State) := ExS.set hs3val
  -- store0
  have haddr0 : EvE Gen.prog (⟨s.locals.upd 3 (.int IntTy.u32 d), s.mem, s.ro⟩ : State)
      (.index (.var 2) (.const (.int IntTy.i32 0)) 1) (.ptr b 0) := by
    refine EvE.index (EvE.var h2) (EvE.const _) ?_
    simp [ptrAdd, IntTy.i32, IntTy.toInt, IntTy.width, IntTy.modulus, isPtr, hmem]
  have hval3 : EvE Gen.prog (⟨s.locals.upd 3 (.int IntTy.u32 d), s.mem, s.ro⟩ : State)
      (.var 3) (.int IntTy.u32 d) := EvE.var (by simp [Locals.upd])
  have hlow0 : EvE Gen.prog (⟨s.locals.upd 3 (.int IntTy.u32 d), s.mem, s.ro⟩ : State)
      (.cast IntTy.u8 (.bin .band (some IntTy.u32) (.var 3)
        (.cast IntTy.u32 (.const (.int IntTy.i32 255)))))
      (.int IntTy.u8 (d % 256)) := by
    refine EvE.cast (EvE.bin hval3 (evCast255 _) (evalBand255 d)) ?_
    simp [evalCast, IntTy.u8, IntTy.u32, IntTy.signed, IntTy.modulus, IntTy.wrap,
      IntTy.toInt, IntTy.width, Nat.mod_mod] <;>
      by_cases hthr : 2147483648 ≤ d % 256 <;> omega
  have hstore0 : ExS Gen.prog (⟨s.locals.upd 3 (.int IntTy.u32 d), s.mem, s.ro⟩ : State)
      (.store (.int IntTy.u8) (.index (.var 2) (.const (.int IntTy.i32 0)) 1)
        (.cast IntTy.u8 (.bin .band (some IntTy.u32) (.var 3)
          (.cast IntTy.u32 (.const (.int IntTy.i32 255)))))) .normal
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256))), s.ro⟩ : State) := by
    refine ExS.store haddr0 hlow0 hro ?_
    exact store_int s.mem b 0 blk hmem IntTy.u8 (d % 256) (by
      simp [IntTy.bytes, IntTy.u8, IntTy.width]; omega)
  -- store1
  have hmemB1 : (s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))) b
      = some (splice blk 0 (encodeLE 1 (d % 256))) := by simp [Mem.upd]
  have hblkI1 : (1 : Int) ≤ ((blk.length : Nat) : Int) := by omega
  have haddr1 : EvE Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256))), s.ro⟩ : State)
      (.index (.var 2) (.const (.int IntTy.i32 1)) 1) (.ptr b 1) := by
    have hloc2 : (⟨s.locals.upd 3 (.int IntTy.u32 d),
        s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256))), s.ro⟩ : State).locals 2
        = some (.ptr b 0) := by
      simp [Locals.upd, h2]
    refine EvE.index (EvE.var hloc2) (EvE.const _) ?_
    simp [ptrAdd, IntTy.i32, IntTy.toInt, IntTy.width, IntTy.modulus, isPtr,
      hmemB1, hlf0, hblkI1]
  have hval3' : EvE Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256))), s.ro⟩ : State)
      (.var 3) (.int IntTy.u32 d) := EvE.var (by simp [Locals.upd])
  have hlow1 : EvE Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256))), s.ro⟩ : State)
      (.cast IntTy.u8 (.bin .band (some IntTy.u32)
        (.bin .shr (some IntTy.u32) (.var 3) (.const (.int IntTy.i32 8)))
        (.cast IntTy.u32 (.const (.int IntTy.i32 255)))))
      (.int IntTy.u8 ((d / 256) % 256)) := by
    refine EvE.cast (EvE.bin (EvE.bin hval3' (EvE.const _)
      (evalShrU d 8 hd (by decide))) (evCast255 _) (evalBand255 (d / 256))) ?_
    simp [evalCast, IntTy.u8, IntTy.u32, IntTy.signed, IntTy.modulus, IntTy.wrap,
      IntTy.toInt, IntTy.width, Nat.mod_mod] <;>
      by_cases hthr : 2147483648 ≤ d / 256 % 256 <;> omega
  have hstore1 : ExS Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256))), s.ro⟩ : State)
      (.store (.int IntTy.u8) (.index (.var 2) (.const (.int IntTy.i32 1)) 1)
        (.cast IntTy.u8 (.bin .band (some IntTy.u32)
          (.bin .shr (some IntTy.u32) (.var 3) (.const (.int IntTy.i32 8)))
          (.cast IntTy.u32 (.const (.int IntTy.i32 255)))))) .normal
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        (s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256))),
        s.ro⟩ : State) := by
    refine ExS.store haddr1 hlow1 hro ?_
    exact store_int (s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))) b 1
      (splice blk 0 (encodeLE 1 (d % 256))) hmemB1 IntTy.u8 ((d / 256) % 256) (by
      rw [hlf0]; simp [IntTy.bytes, IntTy.u8, IntTy.width]; omega)
  -- store2
  have hmemB2 : ((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
      (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))) b
      = some (splice (splice blk 0 (encodeLE 1 (d % 256)))
        1 (encodeLE 1 ((d / 256) % 256))) := by simp [Mem.upd]
  have hblkI2 : (2 : Int) ≤ ((blk.length : Nat) : Int) := by omega
  have haddr2 : EvE Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        (s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256))),
        s.ro⟩ : State)
      (.index (.var 2) (.const (.int IntTy.i32 2)) 1) (.ptr b 2) := by
    have hloc2 : (⟨s.locals.upd 3 (.int IntTy.u32 d),
        (s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256))),
        s.ro⟩ : State).locals 2 = some (.ptr b 0) := by
      simp [Locals.upd, h2]
    refine EvE.index (EvE.var hloc2) (EvE.const _) ?_
    simp [ptrAdd, IntTy.i32, IntTy.toInt, IntTy.width, IntTy.modulus, isPtr,
      hmemB2, hlf1, hblkI2]
  have hval3'' : EvE Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        (s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256))),
        s.ro⟩ : State)
      (.var 3) (.int IntTy.u32 d) := EvE.var (by simp [Locals.upd])
  have hlow2 : EvE Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        (s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256))),
        s.ro⟩ : State)
      (.cast IntTy.u8 (.bin .band (some IntTy.u32)
        (.bin .shr (some IntTy.u32) (.var 3) (.const (.int IntTy.i32 16)))
        (.cast IntTy.u32 (.const (.int IntTy.i32 255)))))
      (.int IntTy.u8 ((d / 65536) % 256)) := by
    refine EvE.cast (EvE.bin (EvE.bin hval3'' (EvE.const _)
      (evalShrU d 16 hd (by decide))) (evCast255 _) (evalBand255 (d / 65536))) ?_
    simp [evalCast, IntTy.u8, IntTy.u32, IntTy.signed, IntTy.modulus, IntTy.wrap,
      IntTy.toInt, IntTy.width, Nat.mod_mod] <;>
      by_cases hthr : 2147483648 ≤ d / 65536 % 256 <;> omega
  have hstore2 : ExS Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        (s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256))),
        s.ro⟩ : State)
      (.store (.int IntTy.u8) (.index (.var 2) (.const (.int IntTy.i32 2)) 1)
        (.cast IntTy.u8 (.bin .band (some IntTy.u32)
          (.bin .shr (some IntTy.u32) (.var 3) (.const (.int IntTy.i32 16)))
          (.cast IntTy.u32 (.const (.int IntTy.i32 255)))))) .normal
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        ((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
          (splice (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))
            2 (encodeLE 1 ((d / 65536) % 256))),
        s.ro⟩ : State) := by
    refine ExS.store haddr2 hlow2 hro ?_
    exact store_int ((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
      (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))) b 2
      (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))
      hmemB2 IntTy.u8 ((d / 65536) % 256) (by
      rw [hlf1]; simp [IntTy.bytes, IntTy.u8, IntTy.width]; omega)
  -- store3
  have hmemB3 : (((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
      (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
      (splice (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))
        2 (encodeLE 1 ((d / 65536) % 256)))) b
      = some (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
        1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256))) := by
    simp [Mem.upd]
  have hblkI3 : (3 : Int) ≤ ((blk.length : Nat) : Int) := by omega
  have haddr3 : EvE Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        ((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
          (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
            1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256))),
        s.ro⟩ : State)
      (.index (.var 2) (.const (.int IntTy.i32 3)) 1) (.ptr b 3) := by
    have hloc2 : (⟨s.locals.upd 3 (.int IntTy.u32 d),
        ((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
          (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
            1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256))),
        s.ro⟩ : State).locals 2 = some (.ptr b 0) := by
      simp [Locals.upd, h2]
    refine EvE.index (EvE.var hloc2) (EvE.const _) ?_
    simp [ptrAdd, IntTy.i32, IntTy.toInt, IntTy.width, IntTy.modulus, isPtr,
      hmemB3, hlf2, hblkI3]
  have hval3''' : EvE Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        ((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
          (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
            1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256))),
        s.ro⟩ : State)
      (.var 3) (.int IntTy.u32 d) := EvE.var (by simp [Locals.upd])
  have hlow3 : EvE Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        ((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
          (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
            1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256))),
        s.ro⟩ : State)
      (.cast IntTy.u8 (.bin .band (some IntTy.u32)
        (.bin .shr (some IntTy.u32) (.var 3) (.const (.int IntTy.i32 24)))
        (.cast IntTy.u32 (.const (.int IntTy.i32 255)))))
      (.int IntTy.u8 ((d / 16777216) % 256)) := by
    refine EvE.cast (EvE.bin (EvE.bin hval3''' (EvE.const _)
      (evalShrU d 24 hd (by decide))) (evCast255 _) (evalBand255 (d / 16777216))) ?_
    simp [evalCast, IntTy.u8, IntTy.u32, IntTy.signed, IntTy.modulus, IntTy.wrap,
      IntTy.toInt, IntTy.width, Nat.mod_mod] <;>
      by_cases hthr : 2147483648 ≤ d / 16777216 % 256 <;> omega
  have hstore3 : ExS Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        ((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
          (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
            1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256))),
        s.ro⟩ : State)
      (.store (.int IntTy.u8) (.index (.var 2) (.const (.int IntTy.i32 3)) 1)
        (.cast IntTy.u8 (.bin .band (some IntTy.u32)
          (.bin .shr (some IntTy.u32) (.var 3) (.const (.int IntTy.i32 24)))
          (.cast IntTy.u32 (.const (.int IntTy.i32 255)))))) .normal
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        (((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
          (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
            1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256)))).upd b
          (splice (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
            1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256)))
            3 (encodeLE 1 ((d / 16777216) % 256))),
        s.ro⟩ : State) := by
    refine ExS.store haddr3 hlow3 hro ?_
    exact store_int (((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
      (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
      (splice (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))
        2 (encodeLE 1 ((d / 65536) % 256)))) b 3
      (splice (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))
        2 (encodeLE 1 ((d / 65536) % 256))) hmemB3 IntTy.u8 ((d / 16777216) % 256) (by
      rw [hlf2]; simp [IntTy.bytes, IntTy.u8, IntTy.width]; omega)
  -- ret 3
  have hret : ExS Gen.prog
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        (((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
          (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
            1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256)))).upd b
          (splice (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
            1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256)))
            3 (encodeLE 1 ((d / 16777216) % 256))),
        s.ro⟩ : State)
      (.ret (some (.cast IntTy.u32 (.const (.int IntTy.i32 3)))))
      (.ret (some (.int IntTy.u32 3)))
      (⟨s.locals.upd 3 (.int IntTy.u32 d),
        (((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
          (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
          (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
            1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256)))).upd b
          (splice (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
            1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256)))
            3 (encodeLE 1 ((d / 16777216) % 256))),
        s.ro⟩ : State) := by
    have hone : EvE Gen.prog
        (⟨s.locals.upd 3 (.int IntTy.u32 d),
          (((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
            (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
            (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
              1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256)))).upd b
            (splice (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
              1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256)))
              3 (encodeLE 1 ((d / 16777216) % 256))),
          s.ro⟩ : State)
        (.cast IntTy.u32 (.const (.int IntTy.i32 3))) (.int IntTy.u32 3) := by
      refine EvE.of_eq 5 (fun f => ?_)
      simp [evalExpr, evalCast, intOf, IntTy.u32, IntTy.i32, IntTy.toInt, IntTy.modulus,
        IntTy.wrap, isPtr, Res.pure_eq, Res.bind_eq, Res.bind_ok]
    exact ExS.ret hone
  -- Final memory: four updates at the same block are one 4-byte write
  have hmemfinal : (((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
      (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
      (splice (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))
        2 (encodeLE 1 ((d / 65536) % 256)))).upd b
      (splice (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
        1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256)))
        3 (encodeLE 1 ((d / 16777216) % 256)))
      = s.mem.upd b (splice blk 0 (encodeLE 4 d)) := by
    funext x
    by_cases hx : x = b
    · simp [Mem.upd, hx, splice_bytes4 blk d hblk]
    · simp [Mem.upd, hx]
  exact ⟨(⟨s.locals.upd 3 (.int IntTy.u32 d),
      (((s.mem.upd b (splice blk 0 (encodeLE 1 (d % 256)))).upd b
        (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))).upd b
        (splice (splice (splice blk 0 (encodeLE 1 (d % 256))) 1 (encodeLE 1 ((d / 256) % 256)))
          2 (encodeLE 1 ((d / 65536) % 256)))).upd b
        (splice (splice (splice (splice blk 0 (encodeLE 1 (d % 256)))
          1 (encodeLE 1 ((d / 256) % 256))) 2 (encodeLE 1 ((d / 65536) % 256)))
          3 (encodeLE 1 ((d / 16777216) % 256))), s.ro⟩ : State),
    ExS.seq hset (ExS.seq hstore0 (ExS.seq hstore1 (ExS.seq hstore2 (ExS.seq hstore3 hret)))),
    hmemfinal⟩

/-- **Whole-function `callFunc` for `encode_delta32` (code 3 branch).**
    `d ≠ common`, neither of the 1-byte and 2-byte guard windows applies, and
    the 4-byte store executes. -/
theorem encode_delta32_call3 (common d b : Nat) (blk : Block) (m : Mem)
    (hc : common < 4294967296) (hd : d < 4294967296)
    (hne : d ≠ common)
    (hskip1 : ¬ ((-128 : Int) ≤ IntTy.toInt IntTy.i32 d
      ∧ IntTy.toInt IntTy.i32 d ≤ 127))
    (hskip2 : ¬ ((-32768 : Int) ≤ IntTy.toInt IntTy.i32 d
      ∧ IntTy.toInt IntTy.i32 d ≤ 32767))
    (hmem : m b = some blk) (hblk : 4 ≤ blk.length) :
    ∃ K, ∀ n, K ≤ n →
      callFunc Gen.prog n Gen.fid_lspec_crate_encode_delta32
        [.int IntTy.i32 common, .int IntTy.i32 d, .ptr b 0] m
      = .ok (some (.int IntTy.u32 3),
          m.upd b (splice blk 0 (encodeLE 4 d))) := by
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
  -- Guard evaluations on the code-1 (-128…127) window.
  have hge128Ev : EvE Gen.prog s0
      (.bin .ge (some IntTy.i32) (.var 1)
        (.un .neg IntTy.i32 (.const (.int IntTy.i32 128))))
      (boolVal (decide (-128 ≤ IntTy.toInt IntTy.i32 d))) :=
    enc_ge_eval d s0 hf1
  have hle127Ev : EvE Gen.prog s0
      (.bin .le (some IntTy.i32) (.var 1) (.const (.int IntTy.i32 127)))
      (boolVal (decide (IntTy.toInt IntTy.i32 d ≤ 127))) :=
    enc_le_eval d s0 hf1
  -- Guard evaluations on the code-2 (-32768…32767) window.
  have hge32768Ev : EvE Gen.prog s0
      (.bin .ge (some IntTy.i32) (.var 1)
        (.un .neg IntTy.i32 (.const (.int IntTy.i32 32768))))
      (boolVal (decide (-32768 ≤ IntTy.toInt IntTy.i32 d))) :=
    enc_ge16_eval d s0 hf1
  have hle32767Ev : EvE Gen.prog s0
      (.bin .le (some IntTy.i32) (.var 1) (.const (.int IntTy.i32 32767)))
      (boolVal (decide (IntTy.toInt IntTy.i32 d ≤ 32767))) :=
    enc_le16_eval d s0 hf1
  obtain ⟨s'', hfrag, hmem2⟩ := encode_byte4_exs b blk d s0 hf1 hf2 hmem rfl hd hblk
  have hWhole : ExS Gen.prog s0 Gen.lspec_crate_encode_delta32.body
      (.ret (some (.int IntTy.u32 3))) s'' := by
    by_cases hge1 : (-128 : Int) ≤ IntTy.toInt IntTy.i32 d
    case neg =>
      -- d < -128 ⇒ d < -32768: both window guards take their else branch.
      have hge2F : ¬ ((-32768 : Int) ≤ IntTy.toInt IntTy.i32 d) := by
        intro hge2; exact hskip2 ⟨hge2, by omega⟩
      have hge1F : EvE Gen.prog s0
          (.bin .ge (some IntTy.i32) (.var 1)
            (.un .neg IntTy.i32 (.const (.int IntTy.i32 128)))) (boolVal false) := by
        have hdec : decide (-128 ≤ IntTy.toInt IntTy.i32 d) = false := by
          rw [decide_eq_false_iff_not]; exact hge1
        rwa [hdec] at hge128Ev
      have hge2Fv : EvE Gen.prog s0
          (.bin .ge (some IntTy.i32) (.var 1)
            (.un .neg IntTy.i32 (.const (.int IntTy.i32 32768)))) (boolVal false) := by
        have hdec : decide (-32768 ≤ IntTy.toInt IntTy.i32 d) = false := by
          rw [decide_eq_false_iff_not]; exact hge2F
        rwa [hdec] at hge32768Ev
      simp only [Gen.lspec_crate_encode_delta32]
      refine ExS.seq (ExS.ite hneEv (truthy_boolVal false) ExS.skip) ?_
      refine ExS.seq (ExS.ite hge1F (truthy_boolVal false) ExS.skip) ?_
      refine ExS.seq (ExS.ite hge2Fv (truthy_boolVal false) ExS.skip) ?_
      exact hfrag
    case pos =>
      -- d ≥ -128 ⇒ (hskip1) d > 127 ⇒ (hskip2) d > 32767.
      have hle1 : ¬ (IntTy.toInt IntTy.i32 d ≤ 127) := fun hle => hskip1 ⟨hge1, hle⟩
      have hle2 : ¬ (IntTy.toInt IntTy.i32 d ≤ 32767) := fun hle2 =>
        hskip2 ⟨by omega, hle2⟩
      have hle1F : EvE Gen.prog s0
          (.bin .le (some IntTy.i32) (.var 1) (.const (.int IntTy.i32 127)))
          (boolVal false) := by
        have hdec : decide (IntTy.toInt IntTy.i32 d ≤ 127) = false := by
          rw [decide_eq_false_iff_not]; exact hle1
        rwa [hdec] at hle127Ev
      have hle2F : EvE Gen.prog s0
          (.bin .le (some IntTy.i32) (.var 1) (.const (.int IntTy.i32 32767)))
          (boolVal false) := by
        have hdec : decide (IntTy.toInt IntTy.i32 d ≤ 32767) = false := by
          rw [decide_eq_false_iff_not]; exact hle2
        rwa [hdec] at hle32767Ev
      have hge2T : EvE Gen.prog s0
          (.bin .ge (some IntTy.i32) (.var 1)
            (.un .neg IntTy.i32 (.const (.int IntTy.i32 32768)))) (boolVal true) := by
        have hdec : decide (-32768 ≤ IntTy.toInt IntTy.i32 d) = true := by
          rw [decide_eq_true_eq]; omega
        rwa [hdec] at hge32768Ev
      have hge1T : EvE Gen.prog s0
          (.bin .ge (some IntTy.i32) (.var 1)
            (.un .neg IntTy.i32 (.const (.int IntTy.i32 128)))) (boolVal true) := by
        have hdec : decide (-128 ≤ IntTy.toInt IntTy.i32 d) = true := by
          rw [decide_eq_true_eq]; exact hge1
        rwa [hdec] at hge128Ev
      simp only [Gen.lspec_crate_encode_delta32]
      refine ExS.seq (ExS.ite hneEv (truthy_boolVal false) ExS.skip) ?_
      refine ExS.seq (ExS.ite hge1T (truthy_boolVal true)
        (ExS.ite hle1F (truthy_boolVal false) ExS.skip)) ?_
      refine ExS.seq (ExS.ite hge2T (truthy_boolVal true)
        (ExS.ite hle2F (truthy_boolVal false) ExS.skip)) ?_
      exact hfrag
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
      (.ret (some (.int IntTy.u32 3))) s'' := by
    simpa [Gen.lspec_crate_encode_delta32] using hWhole
  have hcall := callFunc_of_ExS hf hlen hEx'
  obtain ⟨K, hK⟩ := hcall
  refine ⟨K, fun n hn => ?_⟩
  have h := hK n hn
  rwa [show s''.mem = m.upd b (splice blk 0 (encodeLE 4 d)) from hmem2] at h

end UsdSpecC.Proofs

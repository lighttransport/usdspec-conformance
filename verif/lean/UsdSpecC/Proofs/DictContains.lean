/-
  Dict-contains loop proof: `lspec_dict_contains_u32` searches a block (stride 4, `u32` keys).
  Invariants mirror tinygltf `Proofs/Loop.lean` `LoopFacts`.
  Landed: `dict_loop_exs` fuel induction (`n-i`, `ExS.loop_next`/`loop_brk`/
  `loop_ret`) + whole-function `dict_call` (preamble + loop + `ret 0`
  via `callFunc_of_ExS`; non-empty/non-null case; `Decidable`-free
  disjunctive statement).
-/
import UsdSpecC.Gen
import UsdSpecC.Logic
import UsdSpecC.Hoare
import UsdSpecC.Splice
import UsdSpecC.Proofs.Contains

namespace UsdSpecC.Proofs

open UsdSpecC

set_option linter.unusedSimpArgs false
set_option linter.unusedVariables false
set_option maxRecDepth 4000
set_option linter.deprecated false

/-- What the loop knows about the C state (read-only search). -/
structure DictFacts (b : Nat) (blk : Block) (n : Nat) (v : Nat) (s : State) : Prop where
  l0 : s.locals 0 = some (.ptr b 0)
  l1 : s.locals 1 = some (.int IntTy.u32 n)
  l2 : s.locals 2 = some (.int IntTy.u32 v)
  mb : s.mem b = some blk
  ro : s.ro = false

/-- Loop body after the condition. -/
def dictBody : Stmt :=
  match Gen.lspec_dict_contains_u32_loop0 with
  | .loop (.ite _ b _) _ => b
  | _ => .skip

/-- Loop condition. -/
def dictCond : Expr :=
  match Gen.lspec_dict_contains_u32_loop0 with
  | .loop (.ite c _ _) _ => c
  | _ => .const .null

theorem dict_loop0_eq :
    Gen.lspec_dict_contains_u32_loop0 = .loop (.ite dictCond dictBody .brk)
      (.set 3 (.cast IntTy.u32 (.bin .add (some IntTy.u32)
        (.cast IntTy.u32 (.var 3)) (.const (.int IntTy.u32 1))))) := rfl

/-- Condition evaluates to `i < n`. -/
theorem dict_cond_eval (b : Nat) (blk : Block) (cnt : Nat) (v i : Nat)
    (s : State) (hs : DictFacts b blk cnt v s)
    (h3 : s.locals 3 = some (.int IntTy.u32 i)) :
    EvE Gen.prog s dictCond (boolVal (decide (i < cnt))) := by
  have h1 := hs.l1
  refine EvE.of_eq 5 (fun f => ?_)
  simp only [dictCond, Gen.lspec_dict_contains_u32_loop0]
  simp [evalExpr, evalBin, evalBinInt, binInt, intOf, IntTy.u32, IntTy.toInt, IntTy.modulus,
    isPtr, guard, Res.bind_eq, Res.bind_ok, h1, h3]

/-- The `xs[i] == v` comparison inside the body. The element is the LE
    decode of the 4 bytes at `4*i` (as a u32 representation). -/
theorem dict_body_eq_eval (b : Nat) (blk : Block) (cnt : Nat) (v i : Nat)
    (s : State) (hs : DictFacts b blk cnt v s)
    (h3 : s.locals 3 = some (.int IntTy.u32 i))
    (hblk : 4*i + 4 ≤ blk.length) :
    EvE Gen.prog s
      (.bin .eq (some IntTy.u32)
        (.load (.int IntTy.u32) (.index (.var 0) (.var 3) 4))
        (.var 2))
      (boolVal (decide (decodeLE ((blk.drop (4*i)).take 4) = v))) := by
  have h0 := hs.l0
  have h2 := hs.l2
  have hm := hs.mb
  -- Address: ptr b (4*i)
  have hbase : EvE Gen.prog s (.var 0) (.ptr b 0) := EvE.var h0
  have hidx : EvE Gen.prog s (.var 3) (.int IntTy.u32 i) := EvE.var h3
  have haddr : EvE Gen.prog s (.index (.var 0) (.var 3) 4) (.ptr b (4*i)) := by
    refine EvE.index hbase hidx ?_
    have hmul : i * 4 = 4 * i := Nat.mul_comm i 4
    have hblk' : i * 4 ≤ blk.length := by omega
    simp [ptrAddN, IntTy.u32, hs.mb, hblk', Nat.mul_comm, Nat.zero_add]
  -- Load 4 bytes at that address.
  have hload : EvE Gen.prog s (.load (.int IntTy.u32) (.index (.var 0) (.var 3) 4))
      (.int IntTy.u32 (decodeLE ((blk.drop (4*i)).take 4))) := by
    refine EvE.load haddr ?_
    simp only [load, readBytes, hs.mb, hblk, Ty.size, IntTy.bytes, IntTy.u32, IntTy.width]
    rfl
  have hvar : EvE Gen.prog s (.var 2) (.int IntTy.u32 v) := EvE.var h2
  refine EvE.bin hload hvar ?_
  simp [evalBin, evalBinInt, binInt, intOf, IntTy.u32, IntTy.toInt, IntTy.modulus, IntTy.toInt, isPtr]

/-- Element at index `j` as u32 representation. -/
def dictElem (blk : Block) (j : Nat) : Nat := decodeLE ((blk.drop (4*j)).take 4)

/-- Unsigned key equality for element `j`. -/
def dictElEq (blk : Block) (v j : Nat) : Prop :=
  dictElem blk j = v

/-- **The search loop refines membership.** For `cnt - i < fuel`, the loop
    terminates (no UB) with `ret 1` iff some `j < cnt` has `elem j = v`,
    otherwise `normal` and no such `j` exists. Read-only: `mem` unchanged. -/
theorem dict_loop_exs (b : Nat) (blk : Block) (cnt : Nat) (v : Nat)
    (hcnt : cnt < 4294967296) :
    ∀ (fuel i : Nat) (s : State)
      (hs : DictFacts b blk cnt v s)
      (h3 : s.locals 3 = some (.int IntTy.u32 i))
      (hno : ∀ j, j < i → ¬ dictElEq blk v j)
      (hi : i < 4294967296)
      (hin : i ≤ cnt)
      (hblk : 4 * cnt ≤ blk.length)
      (hfuel : cnt - i < fuel),
      ∃ o s', ExS Gen.prog s Gen.lspec_dict_contains_u32_loop0 o s'
        ∧ s'.mem = s.mem
        ∧ ((o = .ret (some (.int IntTy.u32 1)) ∧ ∃ j, j < cnt ∧ dictElEq blk v j)
          ∨ (o = .normal ∧ ∀ j, j < cnt → ¬ dictElEq blk v j)) := by
  intro fuel
  induction fuel with
  | zero => intro i s hs h3 hno hi hin hblk hfuel; omega
  | succ fuel ih =>
    intro i s hs h3 hno hi hin hblk hfuel
    have hc := dict_cond_eval b blk cnt v i s hs h3
    rw [dict_loop0_eq]
    by_cases hlt : i < cnt
    · have hct := truthy_boolVal (decide (i < cnt))
      simp only [hlt, decide_true] at hc hct
      have hblk_i : 4*i + 4 ≤ blk.length := by omega
      have hbodyEq := dict_body_eq_eval b blk cnt v i s hs h3 hblk_i
      by_cases heq : dictElem blk i = v
      · have hbt := truthy_boolVal (decide (dictElem blk i = v))
        have hdec : decide (dictElem blk i = v) = true :=
          decide_eq_true heq
        rw [hdec] at hbt
        have hdec2 : decide (decodeLE ((blk.drop (4*i)).take 4) = v) = true := by
          simp only [dictElem] at heq
          simp [heq]
        rw [hdec2] at hbodyEq
        have hone : EvE Gen.prog s (.cast IntTy.u32 (.const (.int IntTy.i32 1)))
            (.int IntTy.u32 1) := by
          refine EvE.of_eq 5 (fun f => ?_)
          simp [evalExpr, evalCast, intOf, IntTy.u32, IntTy.i32, IntTy.toInt, IntTy.modulus, IntTy.wrap, isPtr]
        have hret : ExS Gen.prog s (.ret (some (.cast IntTy.u32 (.const (.int IntTy.i32 1)))))
            (.ret (some (.int IntTy.u32 1))) s := ExS.ret hone
        have hbodyRet : ExS Gen.prog s dictBody (.ret (some (.int IntTy.u32 1))) s :=
          ExS.ite hbodyEq hbt hret
        refine ⟨_, _, ExS.loop_ret (ExS.ite hc hct hbodyRet), rfl, Or.inl ⟨rfl, i, hlt, ?_⟩⟩
        exact heq
      · have hbt := truthy_boolVal (decide (dictElem blk i = v))
        have hdec : decide (dictElem blk i = v) = false :=
          decide_eq_false heq
        rw [hdec] at hbt
        have hdec2 : decide (decodeLE ((blk.drop (4*i)).take 4) = v) = false := by
          simp only [dictElem] at heq
          simp [heq]
        rw [hdec2] at hbodyEq
        have hbody : ExS Gen.prog s dictBody .normal s :=
          ExS.ite hbodyEq hbt ExS.skip
        -- step i++
        have hstep0 : ExS Gen.prog s (.set 3 (.cast IntTy.u32 (.bin .add (some IntTy.u32)
            (.cast IntTy.u32 (.var 3)) (.const (.int IntTy.u32 1))))) .normal
            { s with locals := s.locals.upd 3 (.int IntTy.u32 ((i + 1) % 4294967296)) } :=
          ExS.set (step_eval i s h3)
        have hi1 : i + 1 < 4294967296 := by omega
        have hmod : (i + 1) % 4294967296 = i + 1 := by omega
        have hs2 : DictFacts b blk cnt v { s with locals := s.locals.upd 3 (.int IntTy.u32 (i + 1)) } :=
          { l0 := by simp [Locals.upd, hs.l0]
            l1 := by simp [Locals.upd, hs.l1]
            l2 := by simp [Locals.upd, hs.l2]
            mb := hs.mb
            ro := hs.ro }
        have h32 : ({ s with locals := s.locals.upd 3 (.int IntTy.u32 (i + 1)) }).locals 3
            = some (.int IntTy.u32 (i + 1)) := by simp [Locals.upd]
        have hno2 : ∀ j, j < i + 1 → ¬ dictElEq blk v j := by
          intro j hj
          by_cases hji : j < i
          · exact hno j hji
          · have : j = i := by omega
            subst this
            exact heq
        have hstep : ExS Gen.prog s (.set 3 (.cast IntTy.u32 (.bin .add (some IntTy.u32)
            (.cast IntTy.u32 (.var 3)) (.const (.int IntTy.u32 1))))) .normal
            { s with locals := s.locals.upd 3 (.int IntTy.u32 (i + 1)) } := by
          simpa [hmod] using hstep0
        obtain ⟨o, s', hL, hmem, hres⟩ := ih (i+1)
          { s with locals := s.locals.upd 3 (.int IntTy.u32 (i + 1)) }
          hs2 h32 hno2 hi1 (by omega) hblk (by omega)
        refine ⟨o, s', ExS.loop_next (ExS.ite hc hct hbody) (Or.inl rfl) hstep hL, hmem, hres⟩
    · have hct := truthy_boolVal (decide (i < cnt))
      simp only [hlt, decide_false] at hc hct
      have hieq : i = cnt := by omega
      refine ⟨_, _, ExS.loop_brk (ExS.ite hc hct ExS.brk), rfl, Or.inr ⟨rfl, ?_⟩⟩
      intro j hj
      exact hno j (by omega)

/-- **Whole search loop with preamble** (states the loop outcome only;
    whole-function `callFunc` follows by composing preamble + loop +
    final `ret 0` via `ExS.seq`/`seq_ret`). -/
theorem dict_body_exs (b : Nat) (blk : Block) (cnt : Nat) (v : Nat)
    (hcnt : cnt < 4294967296) :
    ∀ (s : State) (hs : DictFacts b blk cnt v s)
      (hblk : 4 * cnt ≤ blk.length),
      ∃ o s', ExS Gen.prog s
        (.seq (.set 3 (.cast IntTy.u32 (.const (.int IntTy.i32 0))))
          Gen.lspec_dict_contains_u32_loop0) o s'
        ∧ s'.mem = s.mem
        ∧ ((o = .ret (some (.int IntTy.u32 1)) ∧ ∃ j, j < cnt ∧ dictElEq blk v j)
          ∨ (o = .normal ∧ ∀ j, j < cnt → ¬ dictElEq blk v j)) := by
  intro s hs hblk
  have hset : ExS Gen.prog s (.set 3 (.cast IntTy.u32 (.const (.int IntTy.i32 0)))) .normal
      { s with locals := s.locals.upd 3 (.int IntTy.u32 0) } := by
    refine ExS.set ?_
    refine EvE.of_eq 5 (fun f => ?_)
    simp [evalExpr, evalCast, intOf, IntTy.u32, IntTy.i32, IntTy.toInt, IntTy.modulus, IntTy.wrap, isPtr]
  have hs2 : DictFacts b blk cnt v { s with locals := s.locals.upd 3 (.int IntTy.u32 0) } :=
    { l0 := by simp [Locals.upd, hs.l0]
      l1 := by simp [Locals.upd, hs.l1]
      l2 := by simp [Locals.upd, hs.l2]
      mb := hs.mb
      ro := hs.ro }
  have h30 : ({ s with locals := s.locals.upd 3 (.int IntTy.u32 0) }).locals 3
      = some (.int IntTy.u32 0) := by simp [Locals.upd]
  have hno : ∀ j, j < 0 → ¬ dictElEq blk v j := by intro j hj; omega
  obtain ⟨o, s', hL, hmem, hres⟩ := dict_loop_exs b blk cnt v hcnt (cnt + 1) 0
    { s with locals := s.locals.upd 3 (.int IntTy.u32 0) } hs2 h30 hno (by omega) (by omega)
    hblk (by omega)
  exact ⟨o, s', ExS.seq hset hL, hmem, hres⟩

/-- **Whole-function `callFunc` for `contains` (non-empty, non-null case).**
    `cnt > 0` skips both preamble `ret 0` branches; the result is `1` iff
    `∃ j < cnt, elEq j`, else `0`. -/
theorem dict_call (b : Nat) (blk : Block) (cnt : Nat) (v : Nat)
    (hcnt : cnt < 4294967296) (hpos : 0 < cnt)
    (hblk : 4 * cnt ≤ blk.length)
    (m : Mem) (hmem : m b = some blk) :
    ∃ K, ∀ n, K ≤ n →
      ((∃ j, j < cnt ∧ dictElEq blk v j) →
        callFunc Gen.prog n Gen.fid_lspec_dict_contains_u32
          [.ptr b 0, .int IntTy.u32 cnt, .int IntTy.u32 v] m
        = .ok (some (.int IntTy.u32 1), m)) ∧
      ((∀ j, j < cnt → ¬ dictElEq blk v j) →
        callFunc Gen.prog n Gen.fid_lspec_dict_contains_u32
          [.ptr b 0, .int IntTy.u32 cnt, .int IntTy.u32 v] m
        = .ok (some (.int IntTy.u32 0), m)) := by
  -- Frame state; preamble conditions are false by `hpos` and `ptr ≠ null`.
  have hframe0 : frameLocals [0, 1, 2]
      [.ptr b 0, .int IntTy.u32 cnt, .int IntTy.u32 v] 0 = some (.ptr b 0) := rfl
  have hframe1 : frameLocals [0, 1, 2]
      [.ptr b 0, .int IntTy.u32 cnt, .int IntTy.u32 v] 1 = some (.int IntTy.u32 cnt) := rfl
  have hframe2 : frameLocals [0, 1, 2]
      [.ptr b 0, .int IntTy.u32 cnt, .int IntTy.u32 v] 2 = some (.int IntTy.u32 v) := rfl
  let s0 : State := ⟨frameLocals [0, 1, 2]
      [.ptr b 0, .int IntTy.u32 cnt, .int IntTy.u32 v], m, false⟩
  have hsFacts : DictFacts b blk cnt v s0 :=
    { l0 := hframe0, l1 := hframe1, l2 := hframe2, mb := hmem, ro := rfl }
  -- Preamble evaluations at s0 (via landed lemmas + decide transport).
  have hnEv : EvE Gen.prog s0
      (.bin .eq (some IntTy.u32) (.var 1) (.cast IntTy.u32 (.const (.int IntTy.i32 0))))
      (boolVal false) := by
    have h := n_zero_eval cnt s0 hframe1
    have hdec : decide (cnt = 0) = false := decide_eq_false (by omega)
    rwa [hdec] at h
  have hxEv : EvE Gen.prog s0 (.bin .eq none (.var 0) (.const .null)) (boolVal false) :=
    null_eval b s0 hframe0
  have hnT : truthy (boolVal false) = .ok false := truthy_boolVal false
  have hxT : truthy (boolVal false) = .ok false := truthy_boolVal false
  -- Body (set + loop) from dict_body_exs (needs DictFacts; i=0 state).
  have hbody : ∃ o s', ExS Gen.prog s0
        (.seq (.set 3 (.cast IntTy.u32 (.const (.int IntTy.i32 0))))
          Gen.lspec_dict_contains_u32_loop0) o s'
      ∧ s'.mem = s0.mem
      ∧ ((o = .ret (some (.int IntTy.u32 1)) ∧ ∃ j, j < cnt ∧ dictElEq blk v j)
        ∨ (o = .normal ∧ ∀ j, j < cnt → ¬ dictElEq blk v j)) :=
    dict_body_exs b blk cnt v hcnt s0 hsFacts hblk
  obtain ⟨o, s', hBody, hmemS, hres⟩ := hbody
  -- Final `ret 0` composition.
  have hret0 : ExS Gen.prog s' (.ret (some (.cast IntTy.u32 (.const (.int IntTy.i32 0)))))
      (.ret (some (.int IntTy.u32 0))) s' := ret_zero_exs s'
  -- Whole-body ExS by outcome (disjunctive, no `if`).
  have hWhole : ∃ o s'', ExS Gen.prog s0 Gen.lspec_dict_contains_u32.body o s''
      ∧ s''.mem = m ∧
      ((o = .ret (some (.int IntTy.u32 1)) ∧ ∃ j, j < cnt ∧ dictElEq blk v j)
        ∨ (o = .ret (some (.int IntTy.u32 0)) ∧ ∀ j, j < cnt → ¬ dictElEq blk v j)) := by
    by_cases hex : ∃ j, j < cnt ∧ dictElEq blk v j
    · have hr : o = .ret (some (.int IntTy.u32 1)) := by
        rcases hres with ⟨h, _⟩ | ⟨_, h⟩
        · exact h
        · exfalso
          obtain ⟨j, hj, he⟩ := hex
          exact h j hj he
      subst hr
      -- Loop returns 1; `seq` propagates ret (seq_ret), mem untouched.
      refine ⟨.ret (some (.int IntTy.u32 1)), s', ?_, hmemS, Or.inl ⟨rfl, hex⟩⟩
      · -- seq(itesskip, seq(itesskip, seq(seq-ret1, ret0))): use ExS.seq_ret chain
        simp only [Gen.lspec_dict_contains_u32]
        refine ExS.seq (ExS.ite hnEv hnT ExS.skip) ?_
        refine ExS.seq (ExS.ite hxEv hxT ExS.skip) ?_
        exact ExS.seq_ret hBody
    · have hnorm : ∀ j, j < cnt → ¬ dictElEq blk v j := by
        rcases hres with ⟨_, h⟩ | ⟨_, h⟩
        · exact absurd h (by simp [hex])
        · exact h
      have hrn : o = .normal := by
        rcases hres with ⟨_, h⟩ | ⟨hr, _⟩
        · exfalso
          obtain ⟨j, hj, he⟩ := h
          exact hex ⟨j, hj, he⟩
        · exact hr
      subst hrn
      refine ⟨.ret (some (.int IntTy.u32 0)), s', ?_, hmemS, Or.inr ⟨rfl, hnorm⟩⟩
      · simp only [Gen.lspec_dict_contains_u32]
        refine ExS.seq (ExS.ite hnEv hnT ExS.skip) ?_
        refine ExS.seq (ExS.ite hxEv hxT ExS.skip) ?_
        refine ExS.seq hBody ?_
        exact hret0
  obtain ⟨o, s'', hEx, hmem2, hor⟩ := hWhole
  have hf : Gen.prog Gen.fid_lspec_dict_contains_u32 = some Gen.lspec_dict_contains_u32 := by
    simp [Gen.prog, Gen.fid_lspec_dict_contains_u32]
  have hlen : Gen.lspec_dict_contains_u32.params.length
      = (([.ptr b 0, .int IntTy.u32 cnt, .int IntTy.u32 v] : List Val).length) := by
    simp [Gen.lspec_dict_contains_u32]
  have hEx' : ExS Gen.prog
      (⟨frameLocals Gen.lspec_dict_contains_u32.params
        [.ptr b 0, .int IntTy.u32 cnt, .int IntTy.u32 v], m, false⟩ :
        State)
      Gen.lspec_dict_contains_u32.body o s'' := by
    simpa [Gen.lspec_dict_contains_u32] using hEx
  rcases hor with ⟨rfl, hex⟩ | ⟨rfl, hall⟩
  · -- Found outcome: result is 1; not-found implication vacuous.
    have hcall := callFunc_of_ExS hf hlen hEx'
    obtain ⟨K, hK⟩ := hcall
    refine ⟨K, fun n hn => ⟨?_, ?_⟩⟩
    · intro _
      simpa [hmem2] using hK n hn
    · intro hall
      exfalso
      obtain ⟨j, hj, he⟩ := hex
      exact hall j hj he
  · -- Not-found outcome: result is 0; found implication vacuous.
    have hcall := callFunc_of_ExS hf hlen hEx'
    obtain ⟨K, hK⟩ := hcall
    refine ⟨K, fun n hn => ⟨?_, ?_⟩⟩
    · intro hex
      exfalso
      obtain ⟨j, hj, he⟩ := hex
      exact hall j hj he
    · intro _
      simpa [hmem2] using hK n hn

end UsdSpecC.Proofs

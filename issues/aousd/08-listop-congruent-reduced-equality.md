# List ops: "congruent ⟹ reduced forms are equal" is false (deleted order is unobservable)

**Type:** erratum
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Foundational Data Types → List Operations → Reducing (L1607-1637) and Chaining (L1688-1697)
**Formal reference:** `verif/lean/UsdSpec/ListOp.lean` — `exists_congruent_reduce_ne` (counterexample), `reduce_congruent_of_congruent'` (true statement), `congruent_iff_apply` (characterization); registry `LEAN-001`

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

L1630-1636:

> Congruent reduced list operations are equivalent.
>
> `A ≅ B ⟹ reduced(A) ≅ reduced(B)`
> `A ≅ B ⟹ reduced(A) = reduced(B)`

and L1690-1697 relies on it ("congruence of reduced list operations implies equality").

Congruence (L1486-1494) only observes `iterate`, and iteration ignores the
deleted sequence entirely (L1387-1388). Equivalence (L1403-1412) compares the
deleted sequences as *ordered* sequences.

### Observation

`A = (delete: ⟨1, 2⟩)` and `B = (delete: ⟨2, 1⟩)` are both reduced and
congruent (every combination with any `C` iterates identically: deletion only
tests membership), but `reduced(A) = A ≠ B = reduced(B)`.

Machine-checked in Lean 4: the second implication is false. For an infinite
element domain, the characterization proves equal reduced `prepended` and
`appended` sequences and equal deleted *sets* for congruent composable ops.
The `[Infinite α]` hypothesis of `reduce_congruent_of_congruent'` is essential
to the stated general characterization; the concrete `Nat` counterexample
itself is unconditional.

### What OpenUSD does

OpenUSD 26.11 agrees with the counterexample (`08-12-lean-demo/run.py`):

```
08 a == b: False | same result on sampled inputs: True
```

The runtime script checks a finite input sample; the universal claim comes from
the Lean proof, not from enumeration.

`SdfListOp::operator==` compares deleted items as ordered vectors, while
`ApplyOperations` only tests membership.

### Request

Either weaken the claim to "reduced forms agree on prepended and appended
sequences and on the *set* of deleted elements", or make the reduced form
canonical for deleted items (e.g. define equivalence of the deleted component
as set equality, or order deleted items canonically in `reduced`).

## Reviewer checklist

- [ ] Quoted text at L1630-1636 and L1690-1697; iteration ignores deletes (L1387-1388).
- [ ] Run `08-12-lean-demo/run.py` with stock OpenUSD; confirm line `08`.
- [ ] `lake build` in `verif/lean` and read `exists_congruent_reduce_ne`.
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "reduced congruent"`.

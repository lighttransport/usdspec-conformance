# Dictionaries: combining `∪` is not associative, so the resolution fold order matters

**Type:** erratum
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Foundational Data Types → Dictionaries → Combining (L1241-1255); Value Resolution → Dictionaries (L6200-6236)
**Formal reference:** `verif/lean/UsdSpec/Dict.lean` — `merge_not_assoc`, `merge_assoc_of_compat`, `keys_merge_assoc`, `resolveDict_ne_resolveDictR`; registry `LEAN-101`, `LEAN-102`

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

L1243-1244: "Combining of two dictionaries in the domain of dictionaries 𝔻 is
a closed and associative operation." The four bullets (L1246-1254) recurse
only when *both* values are dictionaries; otherwise the stronger value wins.

### Observation

With `a = {x: {}}`, `b = {x: 1}`, `c = {x: {y: 2}}` (strongest first):

- `(a ∪ b) ∪ c`: `a ∪ b = {x: {}}`, then both `x` values are dictionaries → `{x: {y: 2}}`
- `a ∪ (b ∪ c)`: `b ∪ c = {x: 1}`, then `a`'s dictionary beats the leaf → `{x: {}}`

Associativity is guaranteed when all operands agree on whether each shared key
holds a dictionary or a leaf (`merge_assoc_of_compat`). Key *sequences* always
associate. Because value resolution (L6200-6206) folds the opinion stack
without fixing the association, two conforming implementations can differ.

### What OpenUSD does

OpenUSD 26.11 resolves a sublayer stack `a > b > c` to the left fold
(`08-12-lean-demo/run.py`):

```
09 stack a>b>c       : {'x': {'y': 2}}
09 (a∪b) over c      : {'x': {'y': 2}}
09 a over (b∪c)      : {'x': {}}
```

LightUSD (`MergeWeakerDictionary`) also folds strongest-first, giving the same result.

### Request

Drop "associative" (or restrict it to shape-compatible operands) and state
the fold in L6200-6206 explicitly: accumulate from the strongest opinion,
merging each weaker opinion into the running result.

## Reviewer checklist

- [ ] Quoted text L1243-1244 and the bullets L1246-1254.
- [ ] Hand-evaluate both associations of the example against the bullets.
- [ ] Run `08-12-lean-demo/run.py`; confirm the three `09` lines.
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "dictionary associative"`.

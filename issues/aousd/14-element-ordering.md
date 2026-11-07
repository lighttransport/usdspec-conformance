# Paths: element-ordering rules, the worked example and OpenUSD disagree

**Type:** erratum
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Paths → Element Ordering (L3516-3559)
**Formal reference:** `verif/lean/UsdSpec/Path/Order.lean` — `elemCompare`, `example_spec_list_not_sorted`, `example_leadingZero_deferred`, `example_underscore_before_digit`; registry `LEAN-201`, `LEAN-204`, `LEAN-205`

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

L3520-3530:

> - `'_'` shall be ordered before all ASCII letters and numbers.
> - ASCII letters shall be case folded and then ordered according to their ASCII values.
> - If ASCII letters differ only in case, upper case letters shall be ordered before lower case letters.
> - ASCII numbers shall be ordered before ASCII letters.
> - ASCII numbers shall be ordered as a group, skipping leading `'0'` values.
> - If a group of ASCII numbers is equal between the two groups and differs only in the number of leading `'0'` values, the group with the lower number of leading `'0'` values shall be ordered first

The worked result (L3549-3559):

```
_foobar
a0
ab
aü
foo_bar
Foobar
foobar
foo00001bar
foo001bar001abc
foo001bar002abc
foo0001bar0002xyz
```

### Observation

1. **The list contradicts "numbers before letters" (LEAN-204).** `foobar` (L3555) precedes
   `foo00001bar` (L3556): at index 3 they compare `b` with `0`, so L3525 puts
   `foo00001bar` first. The same rule is applied the other way in `a0` < `ab` (L3550-3551).
   The stated digit-before-letter rule does not yield the list (`example_spec_list_not_sorted`). By L3520 `foo_bar`
   would also precede `foo00001bar`, but OpenUSD puts it after (item 3).
2. **The leading-zero tie-break position is unspecified (LEAN-201).** Read literally,
   L3528-3530 decide at the digit group: `foo00001bar` vs `foo001bar001abc` compare `1`
   with `1`, so the group with fewer zeros (`foo001…`) is first. The example lists
   `foo00001bar` first (L3556-3557). That order needs the tie-break deferred to the end of
   the string (the shorter remaining string `bar` wins first). Minimal pair:
   `a01a` vs `a1b` — immediate tie-break: `a1b` first; deferred: `a01a` first
   (`example_leadingZero_deferred`).
3. **`_` vs digits (LEAN-205).** L3520 puts `_` before numbers; OpenUSD puts digits first
   (`a0` < `a_`).

### What OpenUSD does

`UsdPrim::GetPropertyNames` uses `TfDictionaryLessThan`
(`pxr/base/tf/stringUtils.cpp`, `_LessImpl`, L760-900 at the tag below: `_` sorts before
letters via `((l + 5) & 31)`; non-letters compare by byte, so `'0'` (0x30) < `'_'` (0x5F);
the leading-zero tie-break is applied only after both strings are exhausted, L885-900; `_` rule L793).
`13-21-lean-demo/run.py` also records the child order of its particular fixture;
child order generally depends on composition and authored ordering.


```
14 pxr order of the L3535-3545 names: ['_foobar', 'a0', 'ab', 'aü', 'foo00001bar', 'foo001bar001abc', 'foo001bar002abc', 'foo0001bar0002xyz', 'foo_bar', 'Foobar', 'foobar']
14 '_' vs digit, children a_ a0 _a: ['_a', 'a0', 'a_']
```

So OpenUSD agrees with the example's deferred tie-break (`foo00001bar` before
`foo001bar001abc`), agrees with "numbers before letters" (all `foo0…` names before
`foo_bar`/`Foobar`/`foobar`), and puts digits before `_` when `_` is not compared with a
letter.

### Request

1. Fix the example to OpenUSD's order (move `foo_bar`, `Foobar`, `foobar` after
   `foo0001bar0002xyz`).
2. State that the leading-zero rule is a final tie-break, applied only when the strings are
   otherwise equal (same as the case tie-break).
3. Either restrict L3520 to "before all ASCII letters" and add "numbers before `_`" (OpenUSD),
   or keep it and note the OpenUSD difference.

## Reviewer checklist

- [ ] Quoted rules L3520-3530 and list L3549-3559 (check the numbering against the vendored copy).
- [ ] Apply the rules by hand to `foobar` vs `foo00001bar` and to `foo00001bar` vs `foo001bar001abc`.
- [ ] Read `TfDictionaryLessThan::_LessImpl` at the tag.
- [ ] Run `13-21-lean-demo/run.py`; confirm the `14` lines.
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "element ordering"` and `"dictionary order"`.

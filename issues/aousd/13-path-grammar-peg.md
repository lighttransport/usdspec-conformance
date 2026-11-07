# Paths: the grammar, read as a PEG, rejects valid paths and admits invalid ones

**Type:** erratum
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Paths → Introduction (L3329-3339, L3378-3381, L3424, L3452, L3485-3489) and Path Grammar → Grammar Definition (L3713-3740), Examples (L3777-3783)
**Formal reference:** `verif/lean/UsdSpec/Path/Grammar.lean` — `Peg.accepts` (literal PEG), `parsePath` (intended language), `peg_rejects_mixed_separators`, `peg_property_asymmetry`, `peg_rejects_double_dotdot`, `spec_intro_variant_example_rejected`; registry `LEAN-202`, `LEAN-203`, `LEAN-206`, `LEAN-207`

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

The grammar is written with PEG operators (`<-`, ordered choice `/`, `&`, `!`).
L3713-3716:

```
PrimElements <- PrimName (&(ForwardSlash PrimName) ForwardSlash PrimName)*  ↵
                (VariantSelections)? /
                PrimName (&(VariantSelections PrimName) VariantSelections PrimName)*  ↵
                (VariantSelections)?
```

L3728-3740:

```
PathElements <- PrimElements (PropElements)* /
                !(PrimElements) PropElements

PrimFirstPathElements <- PrimElements (PropElements)?

Path <- ForwardSlash (PrimFirstPathElements)? /
        Dot Dot (ForwardSlash PathElements)? /
        PathElements /
        Dot
```

Prose: L3424 "Note that a property is a terminal leaf in a path."; L3378-3381
"`../../ParentSibilng/Cousin` is a legal path"; L3784 lists `../..` as a valid path;
L3487-3489 "there is no `/` separator between a variant selector and another variant
selector, nor between a variant selector and a prim spec"; L3338 gives
`/Root/Child/Grandchild{size=1}/GreatGrandchild` as an example path.

### Observation

1. **Mixed separators are unreachable (LEAN-202).** In a PEG the first `PrimElements`
   alternative cannot fail once `PrimName` matched (its repetitions and option may match
   zero times), so the second alternative is never tried. `/a{v=x}b/c`, and the spec's own
   `/World/Foo/Baz{VariantSet1=VarFoobar}Foobar.foobarprop1` (L3452) — where the first
   alternative consumes the variant selection but stops before the following prim name,
   and `Path` has no rule that can continue — are rejected.
   Even read as a CFG, neither alternative permits both slash-separated child
   steps and variant-followed child steps in one sequence. A slash-separated
   prefix followed by a terminal variant selection, such as `/a/b{v=x}`,
   is allowed; that is not the failing case.
2. **Property count is asymmetric (LEAN-203).** `PathElements` allows `(PropElements)*`,
   so the relative `a.b.c` is accepted, while `PrimFirstPathElements` allows one property
   and rejects `/a.b.c`. L3424 says properties are terminal.
3. **Only one `..` (LEAN-206).** `Path` admits `Dot Dot` once; `../..` (L3784) and
   `../../ParentSibilng/Cousin` (L3381) are not derivable.
4. **Intro example is not a path (LEAN-207).** `/Root/Child/Grandchild{size=1}/GreatGrandchild`
   (L3338) puts `/` after a variant selection, which L3487-3489 and both `PrimElements`
   alternatives forbid.

The Lean file mechanises the literal PEG (`Peg.accepts`) and a separate parser
(`parsePath`) that accepts every other example in the chapter; the four theorems above are
decided by evaluation.

### What OpenUSD does

`Sdf.Path.IsValidPathString` (OpenUSD 26.11, `13-21-lean-demo/run.py`):

```
13 IsValidPathString('/a{v=x}b/c') = True
13 IsValidPathString('/World/Foo/Baz{VariantSet1=VarFoobar}Foobar.foobarprop1') = True
13 IsValidPathString('/World/Bar{VariantSet2=VarBarFoo}{VariantSet3=VarBarBar}BarFoo') = True
13 IsValidPathString('a.b.c') = (False, "Ill-formed SdfPath <a.b.c> at character 5 ('c'): expected 'mapper' or 'expression' after '.'")
13 IsValidPathString('/a.b.c') = (False, ...)
13 IsValidPathString('../..') = True
13 IsValidPathString('../../ParentSibilng/Cousin') = True
13 IsValidPathString('/Root/Child/Grandchild{size=1}/GreatGrandchild') = (False, "... at character 31 ('/'): expected end of path")
13 IsValidPathString('/Root/Child/Grandchild{size=1}GreatGrandchild') = True
```

OpenUSD accepts mixed separators and repeated `..`, rejects a second property element, and
rejects the L3338 example.

### Request

1. Rewrite `PrimElements` so that one sequence can mix `/PrimName` and
   `VariantSelections PrimName` steps, e.g.
   `PrimElements <- PrimName ((ForwardSlash / VariantSelections) PrimName)* (VariantSelections)?`.
2. Use `(PropElements)?` in `PathElements` (one terminal property, as in `PrimFirstPathElements`).
3. Allow `Dot Dot (ForwardSlash Dot Dot)*` before the optional `ForwardSlash PathElements`.
4. Fix the L3338 example to `/Root/Child/Grandchild{size=1}GreatGrandchild`.

## Reviewer checklist

- [ ] Quoted grammar L3713-3716, L3728-3740 and prose L3338, L3378-3381, L3424, L3452, L3485-3489, L3784.
- [ ] Check by hand that PEG ordered choice makes the second `PrimElements` alternative unreachable.
- [ ] Run `13-21-lean-demo/run.py`; confirm the `13` lines.
- [ ] `cd verif/lean && lake build` passes (the four theorems are `decide`).
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "path grammar"` and `"variant selection path"`.

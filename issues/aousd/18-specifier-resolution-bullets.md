# Value resolution: the `specifier` bullets overlap, leave gaps, and can contradict OpenUSD

**Type:** erratum
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Value Resolution → Metadata Resolution → specifier (L6118-6131)
**Formal reference:** `verif/lean/UsdSpec/ValueResolution/Metadata.lean` — `resolveSpecifier`, `classBullet`, `defBullet`, `specifier_bullets_overlap`, `specifier_bullets_gap`, `resolveSpecifier_over_iff`; registry `LEAN-701`

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

L6124-6131:

> - *Undefining* (`over`): All contributing opinions for the `specifier` field are `over`
> - *Abstractly Defining* (`class`): The strongest *defining* opinion for `specifier` not from a direct inherit is `class` OR all of the prim's defining specifiers are `class`
> - *Concretely Defining* (`def`): The strongest *defining* opinion for `specifier` is `def` OR the strongest *defining* opinion for `specifier` not from a direct inherit is `def`

### Observation

The `class` and `def` bullets are neither mutually exclusive nor exhaustive. Opinions
strongest first (`demo` files in `13-21-lean-demo/`):

| file | opinions on `/A` | `class` bullet | `def` bullet |
|---|---|---|---|
| `s1.usda` | `over A`, `def C` (direct inherit), `class B` (reference) | true (strongest non-inherit defining is `class B`) | true (strongest defining is `def C`) |
| `s2.usda` | `over A`, `class C1` (direct inherit), `def C2` (direct inherit) | false | false |
| `s3.usda` | `s2` + `class B` (reference) | true | false |

`s1` satisfies both, `s2` neither, `s3` only `class`. Only the `over` bullet is exact
(`resolveSpecifier_over_iff`).

### What OpenUSD does

Stock OpenUSD 26.11 (official `usd-core==26.11` wheel), `13-21-lean-demo/run.py`:

```
18 s1 GetSpecifier() = Sdf.SpecifierDef | stack: [('s1.usda', '/A', 'SpecifierOver'), ('s1.usda', '/C', 'SpecifierDef'), ('s1.usda', '/B', 'SpecifierClass')]
18 s2 GetSpecifier() = Sdf.SpecifierDef | stack: [... '/C1' 'SpecifierClass', '/C2' 'SpecifierDef']
18 s3 GetSpecifier() = Sdf.SpecifierDef | stack: [... '/C1' 'SpecifierClass', '/C2' 'SpecifierDef', '/B' 'SpecifierClass']
```

All three resolve to `def`, including `s3` where only the `class` bullet holds. The
algorithm (`_GetPrimSpecifierImpl`, `pxr/usd/usd/stage.cpp` L6840-6891) scans strongest
first: skip `over`; a `def` wins immediately; a `class` not due to a direct inherit wins
immediately; a `class` due to a direct inherit is remembered and the scan continues; at the
end the remembered value (or `over`) is the result.

### Request

Replace the two defining bullets with the scan above (it is short and exact), e.g.:
"Visit opinions strongest first, ignoring `over`. The first `def` gives `def`. The first
`class` that is not due to a direct inherit gives `class`. If neither is found, the result
is `class` if any `class` opinion was seen, otherwise `over`."

## Reviewer checklist

- [ ] Quoted text L6124-6131.
- [ ] Evaluate both bullets by hand on `s1`, `s2`, `s3`.
- [ ] Run `13-21-lean-demo/run.py`; confirm the three `18` lines.
- [ ] Read `_GetPrimSpecifierImpl` at v26.11.1.
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "specifier"`.

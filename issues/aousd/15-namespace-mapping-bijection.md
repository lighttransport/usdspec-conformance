# Namespace mappings: clarify the partial-bijection domain and consistent pair orientation

**Type:** erratum
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Composition → Namespace Mappings (L5375-5418); Composition Operators → References → Namespace Mapping (L4413-4447), Inherits → Namespace Mapping (L4655-4673), Relocates → Namespace Mapping (L4919-4966)
**Formal reference:** `verif/lean/UsdSpec/Composition/NamespaceMap.lean` — `mapPath`, `mapChecked`, `mapChecked_inverse`, `mapPath_internalRef_not_injective`, `compose_relocates_example`, `compose_relocates_example_noIdentity`; registry `LEAN-511` (confirmed), `LEAN-512`, `LEAN-513` (secondary, see below)

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

L5381-5382: "if a prim `/A` has a reference arc to prim `/B`, then `/B` is the source
namespace and `/A` is the target namespace."

L5384-5387: "Namespace mappings are bijections; as such they can be inverted, and
multiple mappings can be composed together …"

L5389-5395: "a namespace mapping may be represented as a collection of (source path,
target path) pairs. Each pair indicates that any paths in the source namespace at or under
the source path can be transformed to the target namespace by replacing the source path
prefix with the target path. … The latter case represents an identity mapping that maps a
given path to itself."

L4432-4433: "If the reference is an internal reference, the namespace mapping also
includes the identity mapping." L4447 (for `def "A" (references = </B>)`): "the namespace
mapping is **[(`/A`, `/B`), (`/`, `/`)]**." L4430 and L4673 (inherits) print the same
`(/A, /B)` form.

L4962-4966 (relocates `</A/B> : </A/C>`, reference on `/A` to `</Ref>`): "the additional
relocates namespace mapping for `/A` is **[(`/A/B`, `/A/C`)]**. … this mapping composes with
the standard reference namespace mapping **[(`/Ref`, `/A`)]** to produce the final
namespace mapping for the reference arc **[(`/Ref`, `/A`), (`/Ref/B,`/A/C`)]**."

### Observation

1. **Not a bijection (LEAN-511, primary).** For the internal reference of L4440-4447 the
   pairs, written (source, target) per L5389-5390, are `[(/B, /A), (/, /)]`. Prefix
   replacement with the longest matching prefix sends `/B ↦ /A` and, by the identity,
   `/A ↦ /A`: two source paths map to `/A`, so the map is not injective and cannot be
   inverted (`mapPath_internalRef_not_injective`). What holds is a *partial* bijection when
   the result is accepted only if the inverse map sends it back (`mapChecked_inverse`).
2. **Pair orientation (LEAN-512, secondary; by reading).** L4430, L4447 and L4673 print
   `(/A, /B)`, i.e. (target, source), for an arc on `/A` to `/B`; L4965 prints `(/Ref, /A)`,
   i.e. (source, target), for an arc on `/A` to `/Ref`. Only the latter matches L5389-5390.
3. **Implicit identity in the relocates example (LEAN-513, secondary).** Composing
   `[(/A/B, /A/C)]` after `[(/Ref, /A)]` by the L5389-5395 rule gives only
   `[(/Ref/B, /A/C)]`: `/A` has no prefix in the relocates map, so `(/Ref, /A)` is dropped
   (`compose_relocates_example_noIdentity`). The stated result needs the relocates map to
   also contain `(/, /)` (`compose_relocates_example`). The text at L4923-4927 ("adding
   entries to the mapping") suggests that intent but does not say it. (Also a markup typo:
   `` (`/Ref/B,`/A/C\`) `` at L4966.)

### What OpenUSD does

Stock OpenUSD 26.11 (official `usd-core==26.11` wheel; source inspected at `v26.11.1`), `13-21-lean-demo/run.py`:

```
15 MapFunction{(/B,/A),(/,/)}: /B -> /A | /A -> Sdf.Path.emptyPath | /C -> /C
15 relocates∘reference as written (L4962-4966): {Sdf.Path('/Ref/B'): Sdf.Path('/A/C')}
15 same with identity added to the relocates map  : {Sdf.Path('/Ref'): Sdf.Path('/A'), Sdf.Path('/Ref/B'): Sdf.Path('/A/C')}
```

`PcpMapFunction` refuses `/A` because the result would not map back
(`pxr/usd/pcp/mapFunction.cpp` L777-809: "To maintain the bijection, we need to check if the
mapped path would translate back to the original path", with the `{ / -> /,
/_class_Model -> /Model }` example). `PcpMapFunction::Compose` (L1242) reproduces the spec's
relocates result only if the relocates map carries the identity.

### Request

1. Clarify that namespace mappings are partial bijections: mapping a path uses the longest matching
   source prefix, and the result is valid only if mapping it back with the inverted pairs
   returns the original path (otherwise the path does not map). Add the shadowed-target
   case to the L5412-5418 table: its pairs are `(/A, /B)` plus identity,
   so `/B` must map to `<invalid>`. In the reversed `(/B, /A)` example
   used above, the corresponding rejected source is `/A`.
2. Write all example mappings as (source, target): `[(/B, /A), (/, /)]` at L4430/4447/4673.
3. State that the relocates mapping includes the identity `(/, /)` and fix the L4966 markup.

## Reviewer checklist

- [ ] Quoted text L5381-5395, L4430-4447, L4673, L4962-4966.
- [ ] Hand-check that `[(/B,/A),(/,/)]` sends `/A` and `/B` to `/A`.
- [ ] Read `pxr/usd/pcp/mapFunction.cpp` L760-830 and `Compose` at v26.11.1.
- [ ] Run `13-21-lean-demo/run.py`; confirm the `15` lines.
- [ ] Decide whether items 2 and 3 (registry status `candidate`) belong in this issue or are dropped.
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "namespace mapping"` and `"bijection"`.

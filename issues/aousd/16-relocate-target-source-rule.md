# Relocates: "a target path must not be the same as a source path" is ambiguous (per entry vs across entries)

**Type:** clarification
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Composition → Composition Operators → Relocates (L4899-4917); Stage Population → Ordered Prim Children (L5937-5981)
**Formal reference:** `verif/lean/UsdSpec/Composition/Relocates.lean` — `Valid`, `chain_valid_literal`; `verif/lean/UsdSpec/Population/Children.lean` — `rename_target_dropped`; registry `LEAN-514` (confirmed), `LEAN-601` (consequence, secondary)

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

L4899-4910:

> If an entry in the `layerRelocates` field violates any of the following restrictions, it is a composition error and that entry is ignored.
> …
> - Each source path may only have one possible target, and each target may only have one possible source path.
> - A target path must not be the same as a source path.

### Observation

Read per entry (the sentence structure of L4899-4900: "If *an entry* … violates"), the last
bullet only forbids `X → X`. Then the same-layer chain

```
relocates = { </P/A> : </P/B>, </P/C> : </P/A> }
```

is valid: each source has one target, each target one source, and no entry maps a path to
itself (`chain_valid_literal`).

Under that reading the Ordered Prim Children pseudocode (L5975, L5981) then adds both
relocate sources `A` and `C` to `relocated_names` and filters them out at the end, so the
renamed `C` (now `A`) disappears and `/P` gets the children `[B]` (`rename_target_dropped`,
LEAN-601), although L5947-5949 only forbid *stronger* layer stacks from re-introducing a
relocated name.

### What OpenUSD does

OpenUSD v26.11.1 reads the bullet across entries of one layer stack and ignores **both**
entries (`13-21-lean-demo/run.py`, `single.usda` + `refs.usda`):

```
16 children of /P: ['A', 'C']
16 error: Relocation from </P/A> to </P/B> … conflicts with another relocation from </P/C> to </P/A> … and will be ignored
16 error: Relocation from </P/C> to </P/A> … conflicts with another relocation from </P/A> to </P/B> … and will be ignored
```

The full messages are "The source of a relocate cannot be the target of another relocate in
the same layer stack." / "The target of a relocate cannot be the source of another relocate
in the same layer stack." (`pxr/usd/pcp/errors.cpp` L832-837; raised in
`pxr/usd/pcp/layerStack.cpp` L655-663).

This result establishes the stock behavior for the demonstrated conflict. It
does not establish complete relocation validation in LightUSD; that remains a
separate implementation obligation.

### Request

Reword the bullet: "A relocate's target path must not be the source path of any relocate in
the same layer stack (and vice versa); all entries involved are ignored." With that reading
the LEAN-601 situation cannot arise.

## Reviewer checklist

- [ ] Quoted text L4899-4910; pseudocode L5975, L5981; prose L5947-5949.
- [ ] Run `13-21-lean-demo/run.py`; confirm the `16` lines and that `/P` keeps `A`, `C`.
- [ ] Read `pxr/usd/pcp/errors.cpp` and the `ConflictReason` uses in `layerStack.cpp` at v26.11.1.
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "relocates"`.

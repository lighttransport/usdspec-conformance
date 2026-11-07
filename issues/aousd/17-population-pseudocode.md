# Stage population: `populate_stage`, `reorder`, and the children/property pseudocode disagree with OpenUSD

**Type:** erratum
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Stage Population → Populating the Stage (L5839-5899), Ordered Prim Children (L5937-5981), Ordered Property Children (L5987-6004)
**Formal reference:** `verif/lean/UsdSpec/Population/Children.lean` — `reorder`, `listOrderedPrimChildren`, `listOrderedPrimChildren_nodup`, `reorder_ne_pxr`, `dup_without_specs`, `propertyOrder_dup`, module doc (LEAN-602); registry `LEAN-602`, `LEAN-603`, `LEAN-604`, `LEAN-605`

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

L5862-5899 (`populate_stage`), abridged:

```
      while !queue.empty():
        scene_object = queue.dequeue()
        ...
            scene_object.opinions = compose(root_layer, scene_object.path)
        ...
        return create_stage(layer)
```

L5847-5849: "The population mask may also provide a flag indicating whether to load payload
arcs, which can be passed as input to composition of payloads."

L5951-5954:

```
    reorder(names, order) -> reordered:
        unordered_names = [n for n in names if n not in order]
        ordered_names = [o for o in order if o in names]
        return ordered_names + unordered_names
```

L5966-5981 (`list_ordered_prim_children`), abridged:

```
            prim_children = [child if child not in renamed_children else renamed_children[child]
                for child in prim_children]
            prim_children += path_element_sorted(extended_children)
            relocated_names = relocated_names.union(removed_children).union(renamed_children.keys())
            for spec in reversed(layer_stack.strength_ordered_specs):
                prim_children = reorder(unique(prim_children + spec.prim_children),
                                        unique(spec.prim_order))
        return [child_name for child_name in prim_children if child_name not in relocated_names]
```

L6000-6001: `return reorder(path_element_sorted(property_children), scene_object.strongest_authored_property_order)`

### Observation

1. **`populate_stage` (LEAN-602, by reading).** `return create_stage(layer)` (L5899) is
   indented inside the `while` body (L5862), so the function returns after the first
   object. `compose(root_layer, scene_object.path)` (L5870) takes no mask, so the payload
   flag of L5847-5849 never reaches composition.
2. **`reorder` (LEAN-603).** The spec moves all ordered names to the front. For children
   `x a b` and `primOrder = [b, a]` it gives `b a x`; OpenUSD gives `x b a`
   (`reorder_ne_pxr`). OpenUSD keeps unordered names before the first ordered name in place
   and moves each ordered name together with the unordered run that follows it.
3. **Duplicates without a spec (LEAN-604).** `unique` runs only inside the per-spec loop.
   If the layer stack that renames `X → Y` onto an existing sibling `Y` has no spec at that
   path, the result is `[Y, Y]` (`dup_without_specs`); with a spec it is duplicate-free
   (`listOrderedPrimChildren_nodup`).
4. **`propertyOrder` not uniquified (LEAN-605).** Unlike `primOrder` (L5980,
   `unique(spec.prim_order)`), the property order is passed as authored, so
   `reorder properties = ["a", "a"]` over `{a, b}` yields `[a, a, b]` (`propertyOrder_dup`).

### What OpenUSD does

Stock OpenUSD 26.11 (official `usd-core==26.11` wheel), `13-21-lean-demo/run.py`:

```
17 children x a b, primOrder [b,a]: ['x', 'b', 'a']
17 rename X->Y onto existing Y, no /P/C spec in the relocating stack: ['Y']
17 propertyOrder [a,a] over {a,b}: ['a', 'b']
```

(`nospec.usda` relocates `</P/C/X> : </P/C/Y>`; the root layer has `/P` but no `/P/C`.)
Ordering is `SdfApplyListOrdering` → `SdfListOp::_ReorderKeysHelper`
(`pxr/usd/sdf/listOp.cpp` L676-720: it de-duplicates the order, then "Find each item from
the order vector in the scratch list. Then find the next item in the scratch list that's
also in the uniqueOrder vector. All of these items except the last form the next continuous
sequence in the result."), called for prim children from `pxr/usd/pcp/composeSite.cpp`
L534.

### Request

1. Dedent `return create_stage(layer)` out of the loop; pass the population mask (payload
   flag) to `compose`.
2. Specify `reorder` as OpenUSD implements it (or explicitly document the difference), e.g.
   with the `x a b` / `[b, a]` → `x b a` example.
3. Apply `unique` to the merged children once per layer stack (after the rename step), and
   to `strongest_authored_property_order`.

## Reviewer checklist

- [ ] Quoted pseudocode L5855-5899 (check the indentation of L5899), L5951-5954, L5966-5981, L5995-6001.
- [ ] Run `13-21-lean-demo/run.py`; confirm the `17` lines.
- [ ] Hand-run the spec pseudocode for `nospec.usda` (expect `[Y, Y]`).
- [ ] Read `_ReorderKeysHelper` at v26.11.1.
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "primOrder"` and `"populate_stage"`.

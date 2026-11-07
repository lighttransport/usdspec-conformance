# Composition: the outline pseudocode is incomplete, and Example 6 lists opinions from layers that have no spec

**Type:** erratum
**Spec:** USD Core Specification v1.1.0, Composition → Overview → Outline (L4216-4243); Composition Operators → Example 6 (specializes strength ordering) (L5315-5373)
**Formal reference:** `verif/lean/UsdSpec/Composition/PrimIndex.lean` — `compose`, `ex6L`, `ex6_table_ne`; `verif/lean/UsdSpec/Composition/Strength.lean` — `nestedSpecializes_sibling_order`; registry `LEAN-521`, `LEAN-522`

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

L4218-4243:

```
    compose_helper(root_layer, prim_path) -> [(LayerStack, PrimOrVariantPath)]:
        queue = []
        if prim_path == "/":
            queue.append((compose_layer_stack(root_layer), prim_path))
        else:
            ...
            ancestral_opinions = compose_helper(root_layer, prim_path.parent_path)
            for ancestral_layer_stack, ancestral_prim_path in ancestral_opinions:
                queue.append((ancestral_layer_stack,
                              ancestral_prim_path.append(prim_path.name))

        while !queue.empty():
            layer_stack, prim_path = queue.pop()
            compose_arcs(layer_stack, prim_path, queue)

    compose(root_layer, prim_path) -> [(Layer, PrimOrVariantPath)]:
       layer_stack_opinions = compose_helper(root_layer, prim_path)
       opinions = []
       for (layer_stack, path) in layer_stack_opinions:
           for layer in layer_stack:
               if layer.has_spec(path):
                   opinions.append((layer, path))
       return opinions
```

Example 6, "Opinions for `/Root`" (L5352-5359), with `root.usda` containing only `/Root`:

| Layer | Spec Path |
|---|---|
| root.usda | /Root |
| ref.usda | /Ref |
| root.usda | /Class_1 |
| ref.usda | /Class_1 |
| root.usda | /Class_2 |
| ref.usda | /Class_2 |

and the inherits variant (L5366-5373) lists `root.usda /Class_1` and `root.usda /Class_2` too.

### Observation

1. **Outline (LEAN-521, by reading).** `compose_helper` has no `return`, so it does not describe how `compose` obtains the list it iterates. `compose_layer_stack` and `compose_arcs` are not defined anywhere in the document (`grep` finds only these two uses, L4221, L4232). The pseudocode does not define the discipline for `queue.pop`, and it does not state a strength-ordering step. The `queue.append((…` at L4227-4228 has unbalanced parentheses; the notation also uses `!queue.empty()`; the loop rebinds the parameter `prim_path`. The payload flag of the population mask (L5847-5849) has no input here.
2. **Example 6 tables (LEAN-522).** `root.usda` has no `/Class_1` or `/Class_2` spec, so
   `compose` (L4240 `if layer.has_spec(path)`) cannot emit them. They are implied
   specializes/inherits *nodes* of the prim index, not opinions. Also, the `ref.usda`
   listing is not valid USDA: `class "Class_1" (` (L5334) is never closed before `{` (L5336).

### What OpenUSD does

Stock OpenUSD 26.11 (official `usd-core==26.11` wheel), `13-21-lean-demo/run.py` with the example's
files (`ex6_root.usda`, `ex6_ref.usda`, the missing `)` added):

```
20 GetPrimStack: [('ex6_root.usda', '/Root'), ('ex6_ref.usda', '/Ref'), ('ex6_ref.usda', '/Class_1'), ('ex6_ref.usda', '/Class_2')]
20 index   ArcTypeSpecialize ex6_root.usda /Class_1 nospecs
20 index     ArcTypeSpecialize ex6_root.usda /Class_2 nospecs
...
20 inherits variant GetPrimStack: [('ex6i_root.usda', '/Root'), ('ex6i_ref.usda', '/Ref'), ('ex6i_ref.usda', '/Class_1'), ('ex6i_ref.usda', '/Class_2')]
```

The prim stack (the opinions) has four entries in both variants; the `root.usda` class nodes
exist in the index with no specs.

### Request

1. Make the outline self-consistent: return the strength-ordered list, define (or reference
   the sections defining) `compose_layer_stack`/`compose_arcs`, fix the syntax, and say how
   the payload flag is passed.
2. Remove the `root.usda /Class_1` and `/Class_2` rows from both Example 6 tables (or add
   specs for them to `root.usda`, or label the tables as prim index nodes), and close the
   parenthesis at L5335.

## Reviewer checklist

- [x] Quoted pseudocode L4218-4243 and tables L5352-5359, L5366-5373; checked L5334-5336.
- [x] `grep -n 'compose_arcs\|compose_layer_stack' aousd/core/1.1.0/core_spec.md`.
- [x] Ran `13-21-lean-demo/run.py`; confirmed the `20` lines.
- [x] Searched upstream issues and recent commits for duplicates involving "Example 6" and "compose_helper".

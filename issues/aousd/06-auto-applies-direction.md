# Schema Inclusions: the definition of *auto-applies* contradicts its worked examples and `build_prim_definition`

**Type:** erratum / clarification
**Spec:** USD Core Specification v1.1.0, "Schemas" > "Schema Inclusions",
"The Prim Definition", "Fallback Value Resolution for Attributes" (the same
text is in v1.0.1)

### Observation

The definition (L8623-8626) says that auto-applies are the schemas that the
defining schema is applied *to*:

> - A set of *auto-applies*: a set of typed or applied schemas that the
>   defining schema should be applied to, should the prim in the context
>   of a composed stage be of that type or have any of those applied
>   schemas applied to it

So `"FooBar": {"inclusions": {"auto_applies": ["BazFoo:bazfooinstance"]}}`
should mean: "apply `FooBar` to any prim that has `BazFoo:bazfooinstance`."

The rest of the section treats auto-applies as schemas that the defining
schema *pulls in*, like built-ins:

1. Worked example (L8647-8711). With the declaration above, a prim with only
   `apiSchemas = ["FooBar"]` "will have the following applied schemas":
   `FooBar`, `BazFoo:bazfooinstance`, `BarBaz:bazfooinstance`. Under the
   definition, `FooBar` here should not add `BazFoo` at all.
2. `build_prim_definition` (L8765-8776) builds the defining schema's own
   prim definition from its auto-applies:
   ```
   auto_applies = get_auto_applies_inclusion_list(schema_name)
   schema_inclusions = built_ins + auto_applies
   prim_definition.schemas += schema_inclusions
   ```
3. Second example (L8927-8949): `FooBar` with
   `"auto_applies": ["BazFoo:otherInstance"]` gives the order
   `[Bar, FooBar, BarBaz:myInstance, BazFoo:otherInstance]`.

OpenUSD follows the definition. `apiSchemaAutoApplyTo` on an API schema lists
the typed or applied schemas that it is applied to
(`UsdSchemaRegistry::GetAutoApplyAPISchemas`: "names of all registered auto
apply API schemas to the list of type names each is registered to be auto
applied to", `schemaRegistry.h` L404-413 at v26.11.1). A small codeless-schema
demo (`06-07-schema-demo/`, `run.sh`) on OpenUSD 26.11 gives:

```
06: GetAutoApplyAPISchemas: DemoAutoAPI -> ['DemoPrim']  DemoOnAPI -> ['DemoStrongAPI']
06: /typed       type 'DemoPrim' GetAppliedSchemas ['DemoAutoAPI']
06: /autoApplied type ''         GetAppliedSchemas ['DemoAutoAPI']
06: /strongOnly  type ''         GetAppliedSchemas ['DemoStrongAPI', 'DemoOnAPI']
```

A `DemoPrim` prim gets `DemoAutoAPI`, but applying `DemoAutoAPI` does not add
anything. Applying `DemoStrongAPI` pulls in `DemoOnAPI`, because `DemoOnAPI`
declares that it is auto-applied to `DemoStrongAPI`. So to get the example's
result (`FooBar` prims get `BazFoo:bazfooinstance`), OpenUSD needs the
declaration on `BazFoo`, not on `FooBar`.

Two related differences, for information:

- OpenUSD allows `apiSchemaAutoApplyTo` only on single-apply API schemas
  (`usdGenSchema.py`: "should only be used as a customData field on
  single-apply API schemas"). The spec allows any typed or applied schema to
  declare auto-applies, and allows multiple-apply named instances in the list
  (L8645-8646). The example list is `BazFoo:bazfooinstance`, a
  multiple-apply instance.
- In OpenUSD the auto-applied schema does not have to be named on the prim.
  It comes from the registry, and `USD_DISABLE_AUTO_APPLY_API_SCHEMAS` can
  turn it off.

### Request

Please choose one direction and make the definition, both examples and the
algorithm agree:

- **(a) "applied to" (OpenUSD):** an auto-apply rule on schema S lists
  targets T. S is added to every prim whose typed schema is (derived from) T
  or that has T applied. Then fix the examples (move the declaration to
  `BazFoo`, or change the expected results) and remove `auto_applies` from
  the defining schema's own `build_prim_definition`. Also say where the
  auto-applied S goes in the schema order of the final prim definition
  (OpenUSD puts it after the schema it was auto-applied to).
- **(b) "pulls in":** keep the examples and algorithm and reword the
  definition. Then say how this differs from built-ins, and note that it is
  the opposite of OpenUSD's `apiSchemaAutoApplyTo`.

This decides which applied schemas (and so which properties and fallback
values) a conforming implementation gives a prim.

## Reviewer checklist

- [ ] `sha256sum -c SHA256SUMS` in `aousd/core/1.1.0`; quoted lines
      L8623-8626, L8645-8646, L8647-8711, L8765-8776, L8927-8949.
      Also check the 1.0.1 copy (definition L7566, example L7605).
- [ ] Check that I have read the definition sentence correctly ("the defining
      schema should be applied to" those schemas). If another reading fits
      the examples, the draft is wrong.
- [ ] OpenUSD v26.11.1: `schemaRegistry.h` L404-413, `usdGenSchema.py`
      L669-672 (single-apply only), and how `primDefinition` and the
      registry add auto-applied schemas after their target. Is "after the
      schema it was auto-applied to" accurate? The demo shows
      `['DemoStrongAPI', 'DemoOnAPI']` and
      `/both ['DemoStrongAPI', 'DemoOnAPI', 'DemoWeakAPI']`.
- [ ] Re-run `06-07-schema-demo/run.sh` on a stock wheel. The drafter used the
      fork install `dist-v26.11` (README env; `result.txt` is that output).
      The plugin is codeless (plugInfo `Types` + `generatedSchema.usda`), so
      no build is needed.
- [ ] The demo schemas are original (not copied from the spec).
- [ ] Duplicates: `gh issue list -R aousd/specifications-public --state all`
      on 2026-11-04 showed #1, #3-#7. None is about schemas.
- [ ] Remove this checklist before posting (#4-#7 were posted with theirs).

# The Prim Definition: `compose_prim_definition` merges only `default` and `hidden`, while the prose (and OpenUSD) give every field a fallback

**Type:** clarification
**Spec:** USD Core Specification v1.1.0, "Schemas" > "The Prim Definition"
and "Fallback Value Resolution for Attributes" (the same algorithm is in
v1.0.1, L7739)

### Observation

When a property is defined by more than one schema in a prim definition,
`compose_prim_definition` (L8789-8809) fills in only two fields from the
weaker definition:

```
      # the property, check the value of the `default` and `hidden` metadata fields
      # if the stronger property definition has a value for it, skip, otherwise
      # set the value in the stronger property definition
      ...
        metadata_fields = ["default", "hidden"]
```

The prose around it is wider:

- L8747-8748: "A prim definition provides resolving fallbacks not only for a
  property's value, but for any legal prim or property metadatum."
- L8892-8895: "The prim definition for a composed prim defines how to
  evaluate the fallback value of any metadata field that may be authored into
  the prim definition, including but not limited to the `default` field ..."

With the algorithm as written, a field that only a weaker schema provides
(for example `allowedTokens`, `displayName`, `displayGroup`) gets no fallback
on the prim. The prose says it does.

OpenUSD merges every metadata field
(`UsdPrimDefinition::_CreateComposedPrimOrPropertyIfNeeded`,
`pxr/usd/usd/primDefinition.cpp` L513-592 at v26.11.1):

- Every field of the weaker property that the stronger one lacks is copied.
- Exceptions (`_GetDisallowedComposeFromWeakerFields`, L495-511): `custom` and
  `documentation` on properties, and `documentation` on prim metadata.
- Dictionary-valued fields are merged recursively, and `propertyOrder` is
  appended.
- Properties are composed only if their types match (`_PropertyTypesMatch`).

A codeless-schema demo (`06-07-schema-demo/`, `run.sh`) applies
`["DemoStrongAPI", "DemoWeakAPI"]`. Both define `token demo:mode`. The strong
one gives only `default = "a"`. The weak one gives `"b"` plus
`allowedTokens`, `displayName`, `displayGroup`, `doc` and `hidden`. OpenUSD
26.11:

```
07:   demo:mode default       = 'a'
07:   demo:mode allowedTokens = Vt.TokenArray(2, ('a', 'b'))
07:   demo:mode displayName   = 'Mode (weak)'
07:   demo:mode displayGroup  = 'WeakGroup'
07:   demo:mode hidden        = True
07:   demo:mode documentation = None
```

The spec algorithm gives the same `default` and `hidden`, but no
`allowedTokens`, `displayName` or `displayGroup`. Both drop the
documentation, but for different reasons: OpenUSD blocks the field, and the
spec just doesn't list it.

The prim-level case is not covered by the algorithm at all. It composes
`properties` only, yet L8747-8748 says the definition also gives fallbacks for
prim metadata. OpenUSD composes prim metadata through the same function.

The stock schemas don't show a difference that I know of. It shows up as soon
as two schemas declare the same property with different non-`default`
metadata, which is common for override properties and built-ins in domain
schemas.

### Request

Please say which fields a weaker schema contributes when a stronger one
already defines the property. Either:

- **(a)** every field that is not authored on the stronger definition (as in
  OpenUSD), with any exceptions listed (OpenUSD: `custom`, `documentation`)
  and the merge rule for dictionary-valued fields stated; or
- **(b)** only `default` and `hidden`, and then reword L8747-8748 and
  L8892-8895 to match.

Please also say whether prim-level metadata is composed the same way, and
fix the typo `propeerties` (L8801).

## Reviewer checklist

- [ ] `sha256sum -c SHA256SUMS`; quoted lines L8747-8748, L8789-8809,
      L8892-8895, typo at L8801. 1.0.1: `metadata_fields` at L7739.
- [ ] OpenUSD v26.11.1 `pxr/usd/usd/primDefinition.cpp`: blocked-field list
      L495-511, compose function L513-592, `allowedMerge` (dictionary and
      propertyOrder) L535, called from `_AddOrComposeProperty` (around L364-409)
      for both properties and the empty-name prim-metadata entry.
- [ ] Re-run `06-07-schema-demo/run.sh` on a stock wheel. The drafter used the
      fork install `dist-v26.11`; output is in `result.txt`.
- [ ] Is "the stock schemas don't show a difference" true? The audit
      (`doc/validation/aousd11-schema-defs-uihints-2026-11-04.md` rule 17)
      says so but didn't enumerate. Soften it or check it, for example by
      diffing per-field fallbacks for every built-in pair in the OpenUSD
      registry.
- [ ] Duplicates: none in `aousd/specifications-public` (#1, #3-#7 on
      2026-11-04).
- [ ] Remove this checklist before posting.

# UsdCollectionAPI `includeRoot` is documented with fallback `false` but has no schema fallback (`Get()` returns no value)

### Description of Issue

The `includeRoot` docs in `pxr/usd/usd/schema.usda` (v26.11.1 L427-432,
repeated in `collectionAPI.h` L381) say:

> Boolean attribute indicating whether the pseudo-root path `</>` should be
> counted as one of the included target paths.  The fallback is false.

The class doc (L338-344) also says "The fallback value is false." But the
property has no default value:

```
uniform bool includeRoot (
    doc = """..."""
)
```

So `generatedSchema.usda` declares `collection:__INSTANCE_NAME__:includeRoot`
with no fallback. On an unauthored collection, `UsdAttribute::Get()` returns
no value and `HasFallbackValue()` is false. The sibling attributes do have
fallbacks: `expansionRule` resolves to `expandPrims` and `mode` to `automatic`.

Membership is not affected. The C++ code reads the attribute into a local
initialized to `false` (`collectionAPI.cpp` L567-568: `bool includeRoot =
false; GetIncludeRootAttr().Get(&includeRoot);`), so `</>` is not included.
The difference shows only for clients that resolve the attribute value
generically, for example through the prim definition or `Get()` into a
`VtValue`. Those clients see "no value" where the docs promise `false`.

The AOUSD Core Specification (1.0.1 and 1.1, `CollectionAPI` >
`includeRoot`) also lists `Fallback Value: false`, following these docs.

### Steps to Reproduce

```
python repro.py
```

Output with OpenUSD 26.11:

```
Usd.GetVersion(): (0, 26, 11)
includeRoot defined by schema: True
includeRoot HasAuthoredValue: False
includeRoot HasFallbackValue: False
includeRoot Get(): None
membership includes </>: False
  includeRoot   fallback: None
  expansionRule fallback: 'expandPrims'
  mode          fallback: 'automatic'
```

### Expected

Either `uniform bool includeRoot = false (...)` in `schema.usda`, so the
resolved value matches the docs, or docs saying that the attribute
deliberately has no fallback (for example, if the `mode = automatic`
inference is meant to depend on whether it is authored). Which is intended?

### System Information (OS, Hardware)

Linux x86_64.

### Package Versions

OpenUSD v26.11.1. The schema text is unchanged on `dev` (2d39590aa), and
the property also has no default at v24.11 and v25.05.

### Build Flags

Default.

## Reviewer checklist

- [ ] Run `repro.py` on a stock `usd-core==26.11` wheel. The drafter ran it
      only on the fork install `dist-v26.11` (output above, verbatim).
- [ ] `git show v26.11.1:pxr/usd/usd/schema.usda | sed -n 338,344p;427,432p`
      and `generatedSchema.usda` (no `= ...` on includeRoot).
- [ ] `collectionAPI.cpp` L567-568 and `collectionMembershipQuery.cpp`:
      confirm that membership treats unauthored as false.
- [ ] Decide whether the "no fallback" is deliberate. Look at the `mode`
      inference ("the `includeRoot` attribute is set to `true`", L282) and
      commit 2ac3ab047 (adds `mode`) to see whether it relies on no fallback.
      If deliberate, rewrite the draft as a docs request only.
- [ ] Spec line numbers: 1.0.1 `core_spec.md` L8244/L8254, 1.1.0 L9343/L9353.
- [ ] Duplicates: `gh search issues --repo PixarAnimationStudios/OpenUSD
      includeRoot` gave #2377 (open, includeRoot with excludes) and #2258
      (closed, explicitOnly rendering). Neither is about the fallback.
- [ ] Why OpenUSD and not AOUSD: the spec already agrees with OpenUSD's own
      docs. Only OpenUSD's schema data disagrees. If OpenUSD says "no fallback
      is intended", a follow-up spec issue is needed (the spec would then be
      the one that's wrong).

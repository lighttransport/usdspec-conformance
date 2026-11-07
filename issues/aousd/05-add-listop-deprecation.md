# List ops: state the status of the `add` operation (OpenUSD treats it as deprecated)

**Type:** clarification
**Spec:** USD Core Specification v1.1.0, list-op definitions and "A General Note on Listops"

### Observation

The spec lists `add` alongside `prepend`/`append`/`delete`/explicit with no deprecation note.

OpenUSD has moved off it. Commit `7c0651a52` (first released in v26.11) says "The list-op 'add' has long been deprecated in OpenUSD, so update shipped USD files to use append instead". As a result, `usdcat --flatten` now writes the prototype arc of a flattened instance as

```
append references = </Flattened_Prototype_1>
```

where 26.05 and earlier wrote `add references = …`.

### Request

Please say whether `add` is:

- deprecated (writers SHOULD use `append`, readers MUST still accept `add`); and
- semantically identical to `append`. In OpenUSD it is not: `SdfListOp`'s
  "added" items are appended only if not already present and never reorder
  existing items, while "appended" items are moved to the end. So rewriting
  `add` as `append` (as 7c0651a52 does in shipped files) can change the
  composed order whenever an item is already in the list.

This determines whether a conformance check may treat `add X` and `append X` as equivalent when comparing composed or flattened output.

## Reviewer checklist

- [ ] The spec lists `add` without a deprecation note
      (`grep -n -i "\badd\b" aousd/core/1.1.0/core_spec.md | grep -i -E "list|op"`).
- [ ] OpenUSD commit message: `git -C <OpenUSD> show -s 7c0651a52`. Check
      the quoted sentence, and that the first tag containing it is v26.11
      (`git tag --contains 7c0651a52`).
- [ ] Semantics: read `SdfListOp<T>::_AddKeys` (`_InsertIfUnique`) and
      `_AppendKeys` (`_InsertOrMove`) in `pxr/usd/sdf/listOp.cpp`.
- [ ] Write a two-layer demo where `add` and `append` give different
      composed orders (an item already present in a weaker opinion), and add
      it to the draft as evidence. **The draft doesn't have this demo yet.**

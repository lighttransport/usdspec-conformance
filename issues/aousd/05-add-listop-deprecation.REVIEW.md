Item: aousd/05-add-listop-deprecation
Verdict: DO NOT FILE (wrong: the premise is false; the spec already deprecates `add`). A much smaller editorial issue (below) could be filed instead.
Reviewer environment: official PyPI wheels usd-core==26.11 and usd-core==26.5 (Python 3.11, Linux x86_64); OpenUSD git (origin = PixarAnimationStudios/OpenUSD) at v26.11.1; vendored spec 1.1.0 and 1.0.1 (sha256 OK)
Claims checked:
  - [WRONG] "The spec lists `add` alongside prepend/append/delete/explicit with no deprecation note." core_spec.md 1.1.0 L1699-1708, "#### Deprecated Operations": "There are two deprecated operations: `reorder` and `add`. These operations are not normatively specified. ... Hand authored example USD layers sometimes use a single deprecated `add` operation. This content should migrate to using `append`." The same text is in 1.0.1 (L1517-1524). "A General Note on Listops" (L10303ff) lists only explicit/append/prepend/delete. `add` survives only as a grammar token (`ListOp <- 'add' / ...`, L11443) and as the crate "Add Items" bit (L12591), for reading old files. (aousd/04, by the same author, itself says "Core 1.1 gives `add` no normative semantics".)
  - [OK] Commit 7c0651a52 (blevin, 2026-09-24): "The list-op "add" has long been deprecated in OpenUSD, so update shipped USD files to use append instead." It also changes UsdStage::Flatten() for prototypes; "Fixes #3928". First tags containing it: v26.11.0, v26.11.1; not in any 26.05 tag.
  - [OK] Flatten output: the official usd-core 26.5 wheel writes `add references = </Flattened_Prototype_N>`, usd-core 26.11 writes `append references = ...` (historical stock-wheel observation; independent of the list-op counterexample).
  - [OK] Semantics: v26.11.1 pxr/usd/sdf/listOp.cpp: ApplyOperations calls _AddKeys (-> _InsertIfUnique, L551: insert only if absent, no move), then _PrependKeys, _AppendKeys (-> _InsertOrMove, L560: moves an existing item to the end).
  - [OK, demo built] issues/aousd/REVIEW-demo/05-add-vs-append/: weak.usda authors `rel r = [</A>, </B>]`; strong_add.usda / strong_append.usda sublayer it and author `add rel r = </A>` / `append rel r = </A>`. demo.py (also checks bare Sdf.PathListOp.ApplyOperations). Result, identical on usd-core 26.11 and 26.5 (result.txt):
        strong_add.usda     ['/A', '/B']
        strong_append.usda  ['/B', '/A']
    So rewriting `add X` as `append X` changes the composed order when X already comes from a weaker opinion.
Duplicates searched: `gh search issues --repo aousd/specifications-public` "add list", "listop", "deprecat": none. OpenUSD #3928 is the upstream change.
Required edits (if anything is filed):
  - Do not file the draft. Replace it with a one-paragraph editorial request against the existing Note at L1706-1708: "migrate to `append`" is not order-preserving; `add X` is equivalent to `append X` only when X is not already in the weaker list. Suggest the Note say so, or say that a reader converting `add` must use insert-if-absent semantics. Attach the REVIEW-demo files as evidence.
  - Drop the request to "say whether add is deprecated"; it already is, with readers allowed to keep parsing it.

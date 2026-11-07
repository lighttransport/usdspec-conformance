# Independent review summary (2026-11-04)

Nothing was filed, posted or committed by the reviewer. Per-item verdicts: `aousd/0N-*.REVIEW.md`, `OpenUSD/0N-*/REVIEW.md`.
Environment: official PyPI wheels usd-core 26.11 and 26.5 (stock; Python 3.11, Linux x86-64), OpenUSD git at v26.11.1 plus origin/dev, the vendored spec (sha256 OK), the AOUSD corpus 1.0.1.post0.

**Important:** aousd 01-04 were ALREADY FILED, unreviewed, on 2026-11-04 as aousd/specifications-public #4, #5, #6, #7 (author syoyo). The filed bodies are the drafts verbatim and still include the internal "Reviewer checklist" sections. A human should edit them.

| Item | Verdict | Key required edits |
|---|---|---|
| aousd/01 LZ4 framing (filed #4) | FILE AFTER EDITS | Remove the checklist from #4. The count byte is read as a plain (signed) `char`, so the valid range is 0-127, not "unsigned 8-bit". Everything else is verified (fastCompression.cpp, 127-chunk cap, hex dump first byte 0). |
| aousd/02 schema family `_1` (filed #5) | FILE AFTER EDITS | Remove the checklist. All table cells and the PEG hand-parse are verified. Optionally cite OpenUSD's doc string ("positive integer" version). |
| aousd/03 spline Keep Ratio (filed #6) | FILE AFTER EDITS | Remove the checklist. The math and pxr numbers are exact (29.97398957136784 vs exact 29.9742394658737; kWritePadding 1e-5). The draft misses "Value Resolution Compliance" (L643-652), which already allows small deviation without a stated tolerance. Narrow the ask to: exact limit vs padding, ratio change, and whether that clause covers anti-regression. |
| aousd/04 instance target + relocate (filed #7) | FILE AFTER EDITS | Remove the checklist. The 26.05 row is VERIFIED (not UNVERIFIED) with the official usd-core==26.5 wheel: both targets. Add the row "26.05 Pcp = [LBrow pre-relocate], 1 error = corpus baseline". Label rows UsdStage.Flatten/GetConnections. Cite the spec "Namespace Mappings" (L5384-5400): it already covers the unmappable self target; the open question is the sibling class-to-instance target. |
| aousd/05 `add` list-op status | DO NOT FILE (wrong) | The spec already says `add` and `reorder` are deprecated and not normatively specified, and that `add` should migrate to `append` (1.1.0 L1699-1708; same in 1.0.1). A demo was built in `aousd/REVIEW-demo/05-add-vs-append/`: `add` gives [/A,/B] and `append` gives [/B,/A] on 26.11 and 26.5. At most, file a small editorial note that add→append changes order when the item is already present. |
| OpenUSD/01 Usd vs Pcp connection targets | DO NOT FILE as a bug (not a bug). **Status 2026-11-04: reworked into a docs question (ISSUE.md, `Pcp.Cache(usd=True)`; superseded bug framing removed); needs re-review.** | The repro matches on the stock 26.11 and 26.5 wheels. The behaviour is by design: Usd composes targets with PcpComposeTargetPaths and passes no validation cache. The instance-target check only runs with cacheForValidation, and the PcpBuildTargetIndex docs say validation is skipped. dev is unchanged. At most, ask a docs question, using Pcp.Cache(usd=True). |

Reviewer artifacts: `aousd/REVIEW-demo/05-add-vs-append/`. External stock-oracle builds are not part of this repository.

## New drafts after this review (2026-11-04, unreviewed)

| Item | Status |
|---|---|
| aousd/06 auto-applies direction | Draft, not reviewed. The definition text (applied *to*, = OpenUSD `apiSchemaAutoApplyTo`) contradicts the worked examples and `build_prim_definition` (pulls in). Demo: `aousd/06-07-schema-demo/`. |
| aousd/07 prim-definition field merge | Draft, not reviewed. `compose_prim_definition` merges only `default`/`hidden`; the prose and OpenUSD merge every field (except custom/documentation). Same demo. |
| OpenUSD/03 includeRoot fallback | Draft, not reviewed. Filed against OpenUSD, not AOUSD, because the spec agrees with OpenUSD's own docs (fallback `false`) and only OpenUSD's schema lacks the default. Replaces the planned aousd/08. |

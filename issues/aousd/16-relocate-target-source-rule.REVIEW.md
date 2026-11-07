Item: aousd/16-relocate-target-source-rule
Verdict: FILE
Reviewer: independent follow-up session; these drafts predate this review.
Reviewer environment: Linux x86-64, CPython 3.11, official PyPI usd-core==26.11;
source inspected with git show v26.11.1:<path>, not the fork working tree.
Specification: byte-verified core/1.1.0/core_spec.md at published commit
83e25aceb11a9340db4778263bda5d5175875f49. Vendored text was not modified.

Claims checked:
  - [OK] The per-entry reading admits the modeled chain, while the cross-entry reading forbids it.
  - [OK] Tagged layerStack conflict handling and the stock runtime invalidate both entries and keep children A and C.

Runtime evidence: [review output](REVIEW-2026-11-06/stock-13-21.txt).
Formal evidence: lake build, usdspec-test, and committed-vector drift check pass.
This verdict concerns the stated counterexamples and requested clarification;
it does not certify completeness of the whole formalization or C++ implementation.

Duplicates searched: fetched all open/closed issues and the recent commit history
from aousd/specifications-public on 2026-11-06. Retained API responses are in
REVIEW-2026-11-06/upstream-issues.json and upstream-commits.json. Six issues
and the v1.1.0 publication PR were present. No duplicate of this report was found.
Related published reports: [statement separators](https://github.com/aousd/specifications-public/issues/3),
[LZ4 framing](https://github.com/aousd/specifications-public/issues/4), and
[relocated class targets](https://github.com/aousd/specifications-public/issues/7)
cover different defects; local 15–17 and 20 cross-reference their shared context.

Edits applied: Added stock-oracle provenance and a frozen published specification link.
Required edits: none for these checked claims. A human decides whether to file;
no report has been filed by this review.

Scope clarification from the relative-path follow-up: this report uses absolute
valid prim paths and concerns the cross-entry source/target rule only. It does
not report above-root relative-path anchoring as a spec defect: Core 1.1.0
L3370–3375 explicitly forbids it. Stock 26.11 converting such an invalid target
to an empty deletion path is retained separately as malformed-input reference
loss; it is not evidence for this report or a valid-input parity requirement.

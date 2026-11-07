Item: aousd/08-listop-congruent-reduced-equality
Verdict: FILE
Reviewer: independent follow-up session; these drafts predate this review.
Reviewer environment: Linux x86-64, CPython 3.11, official PyPI usd-core==26.11;
source inspected with git show v26.11.1:<path>, not the fork working tree.
Specification: byte-verified core/1.1.0/core_spec.md at published commit
83e25aceb11a9340db4778263bda5d5175875f49. Vendored text was not modified.

Claims checked:
  - [OK] The reduced-delete counterexample survives direct reading of the equivalence and iteration definitions; Lean proves the universal result.
  - [OK] Stock Sdf.IntListOp compares the operations unequal and agrees on the explicitly sampled applications.

Runtime evidence: [review output](REVIEW-2026-11-06/stock-08-12.txt).
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

Edits applied: Distinguished sampled runtime checks from the universal Lean proof.
Required edits: none for these checked claims. A human decides whether to file;
no report has been filed by this review.

Follow-up recheck (2026-11-07): Added the infinite-domain hypothesis of the general list-op characterization; the concrete Nat counterexample remains unconditional.
See [the consolidated recheck](REVIEW-2026-11-07.md) for scope and evidence.
